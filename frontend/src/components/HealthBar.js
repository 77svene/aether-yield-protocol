import React from 'react';

/**
 * @title HealthBar
 * @notice Visualizes the safety of an NFT loan. 
 * Health Factor = (Collateral Value * Liquidation Threshold) / Total Debt.
 * < 1.0 means the loan is eligible for liquidation.
 */
const HealthBar = ({ value, isLoading, error }) => {
  // Theme configuration for consistent styling
  const THEME = {
    critical: '#ef4444', // Red-500
    warning: '#f59e0b',  // Amber-500
    safe: '#10b981',     // Emerald-500
    bg: '#1f2937',       // Gray-800
    text: '#f3f4f6'      // Gray-100
  };

  if (isLoading) {
    return (
      <div style={{ color: THEME.text, fontSize: '0.875rem', animate: 'pulse' }}>
        Calculating Health Factor...
      </div>
    );
  }

  if (error || value === null || value === undefined) {
    return (
      <div style={{ color: THEME.critical, fontSize: '0.875rem', fontWeight: 'bold' }}>
        Error: Could not fetch health data
      </div>
    );
  }

  // Determine color based on risk levels
  const getStatusColor = (hf) => {
    if (hf <= 1.0) return THEME.critical;
    if (hf <= 1.5) return THEME.warning;
    return THEME.safe;
  };

  // We no longer cap the visual bar at 2.0 to avoid misleading the user.
  // Instead, we use a logarithmic-style scale or a wide-range linear scale.
  // For UI purposes, we'll show 1.0 to 5.0 as the primary range.
  const displayValue = parseFloat(value).toFixed(2);
  const percentage = Math.min(Math.max(((value - 1) / 4) * 100, 0), 100);

  const containerStyle = {
    width: '100%',
    backgroundColor: THEME.bg,
    borderRadius: '9999px',
    height: '0.75rem',
    overflow: 'hidden',
    marginTop: '0.5rem',
    marginBottom: '0.25rem',
    border: '1px solid #374151'
  };

  const barStyle = {
    width: `${percentage}%`,
    height: '100%',
    backgroundColor: getStatusColor(value),
    transition: 'width 0.5s ease-in-out'
  };

  const labelStyle = {
    display: 'flex',
    justifyContent: 'space-between',
    fontSize: '0.75rem',
    fontWeight: '600',
    color: THEME.text
  };

  return (
    <div style={{ width: '100%' }}>
      <div style={labelStyle}>
        <span>Health Factor</span>
        <span style={{ color: getStatusColor(value) }}>{displayValue}</span>
      </div>
      <div style={containerStyle}>
        <div style={barStyle} />
      </div>
      <div style={{ ...labelStyle, fontSize: '0.65rem', opacity: 0.7 }}>
        <span>Liquidation @ 1.0</span>
        <span>Target > 2.0</span>
      </div>
    </div>
  );
};

export default HealthBar;