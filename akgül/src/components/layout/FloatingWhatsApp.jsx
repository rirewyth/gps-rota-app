import React from 'react';
import { MessageCircle } from 'lucide-react';
import { config } from '../../data/config';

export default function FloatingWhatsApp() {
  const message = encodeURIComponent(config.waMessage);
  
  return (
    <a 
      href={`${config.waLink}?text=${message}`} 
      target="_blank" 
      rel="noreferrer"
      className="floating-wa"
      aria-label="WhatsApp üzerinden iletişime geçin"
    >
      <MessageCircle size={32} />
    </a>
  );
}
