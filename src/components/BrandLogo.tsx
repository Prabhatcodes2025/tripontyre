type BrandLogoProps = {
  className?: string;
  compact?: boolean;
};

export default function BrandLogo({ className = '', compact = false }: BrandLogoProps) {
  return (
    <span className={`official-brand ${compact ? 'official-brand--compact' : ''} ${className}`.trim()} aria-label="My Tripon Travel Pvt. Ltd.">
      <span className="official-brand__mark" aria-hidden="true"><img src="/tripon-mark-transparent.png" alt="" /></span>
      {!compact && <span className="official-brand__identity" aria-hidden="true"><span className="official-brand__wordmark"><img src="/my-tripon-wordmark-transparent.png" alt="" /></span><span className="official-brand__legal">My Tripon Travel Pvt. Ltd.</span></span>}
    </span>
  );
}
