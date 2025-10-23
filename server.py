from web3 import Web3
import asyncio
import json
import logging
from typing import Dict, Any, List

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

CONFIG = {
    'first_network': {
        'rpc': 'https://sepolia.infura.io/v3/194b46668d4a475abad5d639357a545d',
        'contract_address': '0x63f87ce1DCF2eA022DeEeD21334907070B54Caef',
        'abi_path': 'source_contract_abi.json',
        'chain_id': 11155111 
    },
    'second_network': {
        'rpc': 'https://sepolia.infura.io/v3/194b46668d4a475abad5d639357a545d', 
        'contract_address': '0xe0f62a1324a0cE99c84594D9Ee20665100F30F11',
        'abi_path': 'dest_contract_abi.json',
        'chain_id': 11155111
    },
    'private_key': '0x8bc9da6713e5b2a9d861f6e147034234b47f938be43eb2c4120b19b169bb1d21',
    'poll_interval': 2
}

class CrossChainBridge:
    def __init__(self, config: Dict[str, Any]):
        self.config = config
        
        self.networks = {}
        self.setup_networks()
        
        self.account = self.networks['second_network']['web3'].eth.account.from_key(config['private_key'])
        
    def setup_networks(self):
        for network_name, network_config in self.config.items():
            if network_name in ['private_key', 'poll_interval']:
                continue
                
            try:
                web3 = Web3(Web3.HTTPProvider(network_config['rpc']))
                
                if web3.is_connected():
                    logger.info(f"Connected to {network_name}")
                    
                    with open(network_config['abi_path'], 'r') as f:
                        abi = json.load(f)
                    
                    contract = web3.eth.contract(
                        address=Web3.to_checksum_address(network_config['contract_address']),
                        abi=abi
                    )
                    
                    self.networks[network_name] = {
                        'web3': web3,
                        'contract': contract,
                        'config': network_config
                    }
                    
                else:
                    logger.error(f"Failed to connect to {network_name}")
                    
            except Exception as e:
                logger.error(f"Error setting up {network_name}: {e}")
    
    def setup_event_filters(self):
        event_filters = {}
        
        for network_name, network_data in self.networks.items():
            try:
                contract = network_data['contract']
                
                event_abi = None
                for abi_item in contract.abi:
                    if abi_item['type'] == 'event' and abi_item['name'] == 'Deposited':
                        event_abi = abi_item
                        break
                
                if not event_abi:
                    logger.warning(f"Deposited event not found in ABI for {network_name}")
                    continue
                
                event_filter = contract.events.Deposited.create_filter(
                    fromBlock='latest'
                )
                
                event_filters[network_name] = event_filter
                logger.info(f"Event filter setup for {network_name}")
                
            except Exception as e:
                logger.error(f"Error setting up event filter for {network_name}: {e}")
        
        return event_filters
    
    def handle_deposited_event(self, event, source_network: str):
        try:
            logger.info(f"Received Deposited event from {source_network}: {event}")
            
            event_data = event['args']
            deposit_id = event_data['id']
            depositor = event_data['msg_sender']
            amount = event_data['amount']
            nonce = event_data['nonce'] 
            source_chain_id = event_data['sourceChainId']
            block_number = event_data['blockNumber']
            
            target_network = self.get_target_network(source_network)
            
            self.call_release_method(
                deposit_id, 
                depositor, 
                amount, 
                source_chain_id, 
                target_network
            )
            
        except Exception as e:
            logger.error(f"Error handling Deposited event from {source_network}: {e}")
    
    def get_target_network(self, source_network: str) -> str:
        if source_network == 'first_network':
            return 'second_network'
        elif source_network == 'second_network':
            return 'first_network'
        else:
            raise ValueError(f"Unknown source network: {source_network}")
    
    def call_release_method(self, deposit_id: str, to: str, amount: int, source_chain_id: int, target_network: str):
        try:
            target_network_data = self.networks[target_network]
            contract = target_network_data['contract']
            web3 = target_network_data['web3']
            
            logger.info(f"Calling release in {target_network} for deposit {deposit_id.hex()}")
            
            transaction = contract.functions.release(
                deposit_id,
                Web3.to_checksum_address(to),
                amount,
                source_chain_id
            ).build_transaction({
                'from': self.account.address,
                'nonce': web3.eth.get_transaction_count(self.account.address),
                'gas': 200000,
                'gasPrice': web3.eth.gas_price
            })
            
            signed_txn = web3.eth.account.sign_transaction(
                transaction, self.config['private_key']
            )
            
            tx_hash = web3.eth.send_raw_transaction(signed_txn.rawTransaction)
            logger.info(f"Release transaction sent to {target_network}: {tx_hash.hex()}")
            
            receipt = web3.eth.wait_for_transaction_receipt(tx_hash)
            if receipt.status == 1:
                logger.info(f"Release successful in {target_network}! Tx: {tx_hash.hex()}")
            else:
                logger.error(f"Release failed in {target_network}! Tx: {tx_hash.hex()}")
                
        except Exception as e:
            logger.error(f"Error calling release method in {target_network}: {e}")
    
    async def start_monitoring(self):
        logger.info("Starting event monitoring for both networks...")
        
        event_filters = self.setup_event_filters()
        
        if not event_filters:
            logger.error("No event filters were setup. Exiting.")
            return
        
        while True:
            try:
                for network_name, event_filter in event_filters.items():
                    try:
                        new_entries = event_filter.get_new_entries()
                        
                        for event in new_entries:
                            self.handle_deposited_event(event, network_name)
                            
                    except Exception as e:
                        logger.error(f"Error checking events in {network_name}: {e}")
                        try:
                            event_filters[network_name] = self.networks[network_name]['contract'].events.Deposited.create_filter(
                                fromBlock='latest'
                            )
                            logger.info(f"Recreated event filter for {network_name}")
                        except Exception as filter_error:
                            logger.error(f"Failed to recreate filter for {network_name}: {filter_error}")
                
                await asyncio.sleep(self.config['poll_interval'])
                
            except Exception as e:
                logger.error(f"Error in monitoring loop: {e}")
                await asyncio.sleep(5)

async def main():
    try:
        bridge = CrossChainBridge(CONFIG)
        
        if len(bridge.networks) < 2:
            logger.error("Not all networks are connected. Please check configuration.")
            return
            
        await bridge.start_monitoring()
        
    except Exception as e:
        logger.error(f"Failed to start bridge: {e}")

if __name__ == "__main__":
    asyncio.run(main())