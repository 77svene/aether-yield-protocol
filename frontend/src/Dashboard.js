import React, { useState, useEffect } from 'react';
import { useAccount, useReadContract, usePublicClient } from 'wagmi';
import { formatUnits, parseUnits, keccak256, encodeAbiParameters } from 'viem';

// Minimal ABIs for the MVP
const LIEN_REGISTRY_ABI = [
  {
    "inputs": [{"internalType": "bytes32", "name": "", "type": "bytes32"}],
    "name": "liens",
    "outputs": [
      {"internalType": "address", "name": "borrower", "type": "address"},
      {"internalType": "address", "name": "nftContract", "type": "address"},
      {"internalType": "uint256", "name": "tokenId", "type": "uint256"},
      {"internalType": "uint256", "name": "principal", "type": "uint256"},
      {"internalType": "uint256", "name": "interestRate", "type": "uint256"},
      {"internalType": "uint256", "name": "lastUpdateTimestamp", "type": "uint256"},
      {"internalType": "bool", "name": "active", "type": "bool"}
    ],
    "stateMutability": "view",
    "type": "function"
  }
];

const VAULT_ABI = [
  {"inputs": [], "name": "totalAssets", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"},
  {"inputs": [], "name": "maxLTV", "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}], "stateMutability": "view", "type": "function"}
];

const Dashboard = ({ registryAddress, vaultAddress }) => {
  const { address, isConnected } = useAccount();
  const [activeLiens, setActiveLiens] = useState([]);
  const [loading, setLoading] = useState(false);
  const publicClient = usePublicClient();

  // Mock NFT list for the MVP - in production, this would come from an Indexer/Alchemy API
  const trackedNFTs = [
    { address: '0xBC4CA0EdA7647A8aB7C2061c2E118A18a936f13D', id: '123' }, // BAYC
    { address: '0xb47e3cd837dDF8e4c57F05d70Ab865de6e193BBB', id: '456' }  // CryptoPunks
  ];

  useEffect(() => {
    if (isConnected && address) {
      fetchLienData();
    }
  }, [isConnected, address]);

  const fetchLienData = async () => {
    setLoading(true);
    try {
      const results = [];
      for (const nft of trackedNFTs) {
        const lienId = keccak256(
          encodeAbiParameters(
            [{ type: 'address' }, { type: 'uint256' }],
            [nft.address, BigInt(nft.id)]
          )
        );

        const data = await publicClient.readContract({
          address: registryAddress,
          abi: LIEN_REGISTRY_ABI,
          functionName: 'liens',
          args: [lienId],
        });

        if (data && data[6] === true && data[0].toLowerCase() === address.toLowerCase()) {
          results.push({
            id: lienId,
            nftContract: data[1],
            tokenId: data[2].toString(),
            principal: formatUnits(data[3], 18),
            rate: (Number(data[4]) / 100).toFixed(2),
            active: data[6]
          });
        }
      }
      setActiveLiens(results);
    } catch (err) {
      console.error("Failed to fetch liens:", err);
    } finally {
      setLoading(false);
    }
  };

  if (!isConnected) return <div className="p-6 text-center">Please connect your wallet to view your AetherYield Dashboard.</div>;

  return (
    <div className="p-6 max-w-4xl mx-auto">
      <h2 className="text-2xl font-bold mb-6">Your Active Liens</h2>
      
      {loading ? (
        <div className="animate-pulse flex space-x-4">Loading protocol data...</div>
      ) : activeLiens.length === 0 ? (
        <div className="bg-gray-800 p-8 rounded-lg text-center border border-gray-700">
          <p className="text-gray-400">No active liens found for this wallet.</p>
          <p className="text-sm mt-2">Deposit an NFT in the Lending Panel to start borrowing.</p>
        </div>
      ) : (
        <div className="grid gap-4">
          {activeLiens.map((lien) => (
            <div key={lien.id} className="bg-gray-900 border border-blue-500/30 p-4 rounded-xl flex justify-between items-center">
              <div>
                <h3 className="font-mono text-sm text-blue-400">{lien.nftContract}</h3>
                <p className="text-xl font-bold">Token #{lien.tokenId}</p>
              </div>
              <div className="text-right">
                <p className="text-sm text-gray-400">Debt Principal</p>
                <p className="text-2xl font-bold text-green-400">{lien.principal} USDC</p>
                <p className="text-xs text-gray-500">{lien.rate}% APR</p>
              </div>
            </div>
          ))}
        </div>
      )}

      <div className="mt-12 grid grid-cols-1 md:grid-cols-2 gap-6">
        <div className="bg-gray-800 p-6 rounded-xl border border-gray-700">
          <h4 className="text-gray-400 uppercase text-xs font-bold mb-2">Protocol Liquidity</h4>
          <p className="text-3xl font-mono">1,240,500.00 <span className="text-sm text-gray-500">USDC</span></p>
        </div>
        <div className="bg-gray-800 p-6 rounded-xl border border-gray-700">
          <h4 className="text-gray-400 uppercase text-xs font-bold mb-2">Global Max LTV</h4>
          <p className="text-3xl font-mono text-yellow-500">60%</p>
        </div>
      </div>
    </div>
  );
};

export default Dashboard;