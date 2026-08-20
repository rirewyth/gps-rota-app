import React, { useEffect, useState } from 'react';
import { Helmet, HelmetProvider } from 'react-helmet-async';
import Header from './components/layout/Header';
import Footer from './components/layout/Footer';
import FloatingWhatsApp from './components/layout/FloatingWhatsApp';
import LoadingScreen from './components/layout/LoadingScreen';
import Hero from './components/sections/Hero';
import ScrollStory from './components/sections/ScrollStory';
import ServiceStory from './components/sections/ServiceStory';
import MovingProcess from './components/sections/MovingProcess';
import QuoteForm from './components/sections/QuoteForm';
import Contact from './components/sections/Contact';
import { setupScrollTrigger } from './animations/scrollTriggerSetup';

function App() {
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Basic loading simulation for the experience
    const timer = setTimeout(() => {
      setLoading(false);
      // Wait for next tick so DOM is fully rendered before GSAP measures
      setTimeout(setupScrollTrigger, 50);
    }, 2000);
    return () => clearTimeout(timer);
  }, []);

  return (
    <HelmetProvider>
      <Helmet>
        <title>Akgül Taşımacılık | Profesyonel Lojistik & Taşımacılık</title>
        <meta name="description" content="Akgül Taşımacılık ile profesyonel asansörlü taşımacılık hizmetleri. Sorunsuz taşınma deneyimi için bizimle iletişime geçin." />
      </Helmet>

      {loading && <LoadingScreen />}

      <Header />
      
      <main style={{ position: 'relative', zIndex: 10 }}>
        {/* Abstract Background Design Elements */}
        <div className="bg-grid"></div>
        <div className="bg-glow"></div>

        {/* Scrollable Content Layers */}
        <Hero />
        <ScrollStory />
        <ServiceStory />
        <MovingProcess />
        <QuoteForm />
        <Contact />
      </main>

      <Footer />
      <FloatingWhatsApp />
    </HelmetProvider>
  );
}

export default App;
