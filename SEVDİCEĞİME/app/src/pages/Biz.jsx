import React from 'react';
import { Heart } from 'lucide-react';

const Biz = () => {
  return (
    <div className="space-y-8 flex flex-col items-center py-6">
      
      <div className="text-center">
        <h1 className="text-3xl font-serif text-primary">Senin İçin Bir Köşe ❤️</h1>
      </div>

      <div className="card text-center relative overflow-hidden bg-white/50 backdrop-blur-sm border-primary/20">
        <Heart className="absolute -top-10 -right-10 text-rose-50 w-48 h-48 fill-rose-50 opacity-50" />
        <div className="relative z-10 space-y-4 text-text leading-relaxed">
          <p>
            “Bu siteyi sadece ne yediğini takip et diye yapmadım.
          </p>
          <p>
            Kendine iyi bakmanı istediğim için yaptım.
          </p>
          <p>
            Çünkü sen benim için çok değerlisin.
          </p>
          <p>
            Her gün biraz daha sağlıklı, biraz daha mutlu olmanı istiyorum.
          </p>
          <p className="font-medium text-primary">
            Ve ne olursa olsun, yanında olduğumu bilmeni istiyorum. ❤️”
          </p>
        </div>
      </div>

      <div className="w-full">
        <h2 className="text-2xl font-serif text-primary mb-4 flex items-center gap-2">
          📸 Bizden Kareler
        </h2>
        <div className="grid grid-cols-2 gap-4">
          <div className="aspect-square bg-rose-100 rounded-2xl flex items-center justify-center shadow-inner border border-rose-200">
            <span className="text-rose-400 text-sm font-medium">İlk fotoğrafımız</span>
          </div>
          <div className="aspect-square bg-rose-100 rounded-2xl flex items-center justify-center shadow-inner border border-rose-200">
            <span className="text-rose-400 text-sm font-medium">En güzel anımız</span>
          </div>
          <div className="aspect-square bg-rose-100 rounded-2xl flex items-center justify-center shadow-inner border border-rose-200 col-span-2">
            <span className="text-rose-400 text-sm font-medium">+ Fotoğraf Ekle</span>
          </div>
        </div>
      </div>

      <div className="card w-full text-center py-6 bg-gradient-to-br from-primary/5 to-secondary/10">
        <h3 className="text-sm font-medium text-muted mb-2">İlk Tanıştığımızdan Beri</h3>
        <p className="text-2xl font-serif text-primary font-bold">Her Gün Biraz Daha ❤️</p>
      </div>

      <div className="h-8"></div>
    </div>
  );
};

export default Biz;
