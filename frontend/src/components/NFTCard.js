import React from 'react';
import HealthBar from './HealthBar';

/**
 * @title NFTCard
 * @notice Displays NFT metadata alongside its financial status in the AetherYield protocol.
 */
const NFTCard = ({ 
  nft, 
  onManage, 
  isCollateral = false, 
  healthFactor = 0, 
  loanAmount = "0",
  floorPrice = "0" 
}) => {
  const { name, image, tokenId, collectionName, address } = nft;

  // Determine status color based on health factor
  const getStatusColor = (hf) => {
    if (!isCollateral) return 'text-gray-400';
    if (hf > 1.5) return 'text-green-500';
    if (hf > 1.1) return 'text-yellow-500';
    return 'text-red-500';
  };

  return (
    <div className="bg-gray-900 border border-gray-800 rounded-xl overflow-hidden hover:border-blue-500 transition-colors group">
      {/* Image Container */}
      <div className="relative aspect-square overflow-hidden bg-gray-800">
        <img 
          src={image || 'https://via.placeholder.com/400?text=No+Image'} 
          alt={name}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-300"
        />
        {isCollateral && (
          <div className="absolute top-2 right-2 bg-blue-600 text-white text-xs font-bold px-2 py-1 rounded shadow-lg">
            LIEN ACTIVE
          </div>
        )}
      </div>

      {/* Content */}
      <div className="p-4">
        <div className="mb-1">
          <span className="text-xs text-gray-500 uppercase tracking-wider font-semibold">
            {collectionName}
          </span>
          <h3 className="text-white font-bold truncate">{name} #{tokenId}</h3>
        </div>

        <div className="grid grid-cols-2 gap-4 my-4">
          <div>
            <p className="text-xs text-gray-500 uppercase">Floor Price</p>
            <p className="text-sm font-mono text-white">{floorPrice} ETH</p>
          </div>
          <div>
            <p className="text-xs text-gray-500 uppercase">Debt</p>
            <p className="text-sm font-mono text-white">{loanAmount} USDC</p>
          </div>
        </div>

        {isCollateral && (
          <div className="mb-4">
            <div className="flex justify-between items-center mb-1">
              <span className="text-xs text-gray-500 uppercase">Health Factor</span>
              <span className={`text-xs font-bold ${getStatusColor(healthFactor)}`}>
                {parseFloat(healthFactor).toFixed(2)}
              </span>
            </div>
            <HealthBar healthFactor={healthFactor} />
          </div>
        )}

        <button
          onClick={() => onManage(nft)}
          className={`w-full py-2 rounded-lg font-bold text-sm transition-colors ${
            isCollateral 
              ? 'bg-gray-800 text-white hover:bg-gray-700' 
              : 'bg-blue-600 text-white hover:bg-blue-500'
          }`}
        >
          {isCollateral ? 'Manage Loan' : 'Borrow Against NFT'}
        </button>
      </div>
    </div>
  );
};

export default NFTCard;