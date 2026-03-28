import React, { useState } from 'react';
import { useAccount, useWriteContract, useWaitForTransactionReceipt, useReadContract } from 'wagmi';
import { parseUnits, formatUnits } from 'viem';

const VAULT_ABI = [
  {
    "inputs": [
      {"internalType": "address", "name": "nft", "type": "address"},
      {"internalType": "uint256", "name": "tokenId", "type": "uint256"},
      {"internalType": "uint256", "name": "amount", "type": "uint256"}
    ],
    "name": "borrow",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

const ERC20_ABI = [
  {"inputs": [], "name": "decimals", "outputs": [{"internalType": "uint8", "name": "", "type": "uint8"}], "stateMutability": "view", "type": "function"},
  {"inputs": [{"internalType": "address", "name": "account", "type": "address"}], "name": "balanceOf", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"}
];

export default function LendingPanel({ vaultAddress, assetAddress }) {
  const { address, isConnected } = useAccount();
  const [nftAddr, setNftAddr] = useState('');
  const [tokenId, setTokenId] = useState('');
  const [amount, setAmount] = useState('');

  const { data: decimals } = useReadContract({
    address: assetAddress,
    abi: ERC20_ABI,
    functionName: 'decimals',
  });

  const { data: hash, writeContract, isPending } = useWriteContract();

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  });

  const handleBorrow = async (e) => {
    e.preventDefault();
    if (!nftAddr || !tokenId || !amount || !vaultAddress) return;

    // USDC usually has 6 decimals, WETH 18. We fetch dynamically or fallback to 18.
    const unitDecimals = decimals || 18;
    const parsedAmount = parseUnits(amount, unitDecimals);

    writeContract({
      address: vaultAddress,
      abi: VAULT_ABI,
      functionName: 'borrow',
      args: [nftAddr, BigInt(tokenId), parsedAmount],
    });
  };

  if (!isConnected) return <div className="p-4 border rounded bg-gray-50">Connect wallet to borrow.</div>;

  return (
    <div className="p-6 border rounded-lg shadow-sm bg-white">
      <h2 className="text-xl font-bold mb-4">Borrow Against NFT</h2>
      <form onSubmit={handleBorrow} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">NFT Contract Address</label>
          <input
            type="text"
            className="mt-1 block w-full border rounded-md p-2"
            placeholder="0x..."
            value={nftAddr}
            onChange={(e) => setNftAddr(e.target.value)}
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Token ID</label>
          <input
            type="number"
            className="mt-1 block w-full border rounded-md p-2"
            placeholder="1"
            value={tokenId}
            onChange={(e) => setTokenId(e.target.value)}
            required
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Borrow Amount (USDC/Asset)</label>
          <input
            type="number"
            step="any"
            className="mt-1 block w-full border rounded-md p-2"
            placeholder="100.00"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            required
          />
        </div>
        <button
          type="submit"
          disabled={isPending || isConfirming}
          className="w-full bg-blue-600 text-white py-2 rounded-md hover:bg-blue-700 disabled:bg-gray-400"
        >
          {isPending ? 'Confirming...' : isConfirming ? 'Waiting for Block...' : 'Execute Loan'}
        </button>
      </form>

      {isSuccess && (
        <div className="mt-4 p-3 bg-green-100 text-green-700 rounded">
          Loan successful! TX: <a href={`https://etherscan.io/tx/${hash}`} target="_blank" rel="noreferrer" className="underline">{hash.slice(0, 10)}...</a>
        </div>
      )}
    </div>
  );
}