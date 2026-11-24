(() => {
  const stage = document.querySelector('#terrain');
  const canvas = stage?.querySelector('canvas');
  const controls = document.querySelector('.scene-controls');
  if (!stage || !controls) return;

  const stops = [
    { title: 'Patika başlangıcı', body: 'Yürüyüş rotanız bu noktadan başlıyor.', x: .35, y: .48 },
    { title: 'Su kaynağı', body: 'Rotanızdaki mola noktasını ve ekibinizin konumunu keşfedin.', x: .62, y: .39 },
    { title: 'Zirve noktası', body: 'Yükseldikçe rota iziniz ve irtifa değişimi görünür.', x: .8, y: .28 },
  ];
  const buttons = [...controls.querySelectorAll('.scene-point')];
  const title = controls.querySelector('.scene-readout strong');
  const description = controls.querySelector('.scene-readout span');
  let drag = null;
  let rotationX = 0;
  let rotationY = 0;
  let zoom = 1;

  const render = () => {
    if (!canvas) return;
    canvas.style.transform = `perspective(1200px) rotateX(${rotationX}deg) rotateY(${rotationY}deg) scale(${zoom})`;
  };

  buttons.forEach((button, index) => {
    button.addEventListener('click', () => {
      const stop = stops[index];
      buttons.forEach((item, i) => item.classList.toggle('active', i === index));
      title.textContent = stop.title;
      description.textContent = stop.body;
      rotationY = (index - 1) * 3.5;
      rotationX = (1 - index) * 1.2;
      stage.dispatchEvent(new PointerEvent('pointermove', {
        clientX: innerWidth * stop.x,
        clientY: innerHeight * stop.y,
        bubbles: true,
      }));
      render();
    });
  });

  stage.addEventListener('pointerdown', (event) => {
    if (event.target !== canvas || event.button !== 0) return;
    drag = { x: event.clientX, y: event.clientY, rotationX, rotationY };
    stage.classList.add('dragging');
    stage.setPointerCapture?.(event.pointerId);
  });
  stage.addEventListener('pointermove', (event) => {
    if (!drag) return;
    rotationY = Math.max(-15, Math.min(15, drag.rotationY + (event.clientX - drag.x) * .12));
    rotationX = Math.max(-8, Math.min(8, drag.rotationX - (event.clientY - drag.y) * .07));
    render();
  });
  const release = () => { drag = null; stage.classList.remove('dragging'); };
  stage.addEventListener('pointerup', release);
  stage.addEventListener('pointercancel', release);

  stage.addEventListener('wheel', (event) => {
    if (innerWidth < 800) return;
    zoom = Math.max(.92, Math.min(1.12, zoom - event.deltaY * .00025));
    render();
  }, { passive: true });

  render();
})();
