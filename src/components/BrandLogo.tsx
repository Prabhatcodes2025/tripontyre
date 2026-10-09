type BrandLogoProps = {
  className?: string;
  compact?: boolean;
};

export default function BrandLogo({ className = '', compact = false }: BrandLogoProps) {
  return (
    <span className={`official-brand ${compact ? 'official-brand--compact' : ''} ${className}`.trim()} aria-label="My Tripon Travel">
      <span className="official-brand__mark" aria-hidden="true"><img src="/tripon-mark-transparent.png" alt="" /></span>
      {!compact && <span className="official-brand__wordmark" aria-hidden="true"><img src="/my-tripon-wordmark-transparent.png" alt="" /></span>}
    </span>
  );
}
