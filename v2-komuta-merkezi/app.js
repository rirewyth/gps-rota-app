// --- Data Visualization Engineer: Map Setup ---
// Initialize Leaflet map centered on Turkey
const map = L.map('map', {
    zoomControl: false // Custom position if needed, or hide to keep it clean
}).setView([39.0, 35.0], 6);

// Move zoom control to bottom right
L.control.zoom({ position: 'bottomright' }).addTo(map);

// Add Dark Matter CartoDB tile layer for a sleek, modern UI look
L.tileLayer('https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png', {
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OSM</a> &copy; <a href="https://carto.com/attributions">CARTO</a>',
    subdomains: 'abcd',
    maxZoom: 19
}).addTo(map);


// --- Backend Architect (Mock) & Frontend Developer: Logic ---

// Teams & Markers State
const teams = [
    { id: 'Alfa', lat: 41.0082, lng: 28.9784, status: 'normal' }, // Istanbul
    { id: 'Bravo', lat: 39.9208, lng: 32.8541, status: 'normal' }, // Ankara
    { id: 'Delta', lat: 38.4237, lng: 27.1428, status: 'normal' }, // Izmir
    { id: 'Echo', lat: 36.8969, lng: 30.7133, status: 'normal' }, // Antalya
    { id: 'Foxtrot', lat: 37.0662, lng: 37.3833, status: 'normal' } // Gaziantep
];

const markers = {};
let alertCount = 0;
let totalRoutes = 1204;

// Custom Icons via Frontend Developer & Whimsy Injector
const createIcon = (status) => {
    return L.divIcon({
        className: 'custom-div-icon',
        html: `<div class="${status === 'danger' ? 'pulse-danger' : 'pulse-marker'}"></div>`,
        iconSize: [20, 20],
        iconAnchor: [10, 10]
    });
};

// Initialize Markers
teams.forEach(team => {
    const marker = L.marker([team.lat, team.lng], { icon: createIcon(team.status) }).addTo(map);
    marker.bindPopup(`<b class="text-slate-800">Ekip ${team.id}</b><br>Durum: ${team.status.toUpperCase()}`);
    markers[team.id] = marker;
});

// Update Top Stats
function updateStats() {
    document.getElementById('stat-active').innerText = teams.length;
    document.getElementById('stat-routes').innerText = totalRoutes.toLocaleString();
    
    const alertEl = document.getElementById('stat-alerts');
    const alertText = document.getElementById('stat-alerts-text');
    
    alertEl.innerText = alertCount;
    if (alertCount > 0) {
        alertEl.classList.remove('text-brand-accent');
        alertEl.classList.add('text-red-500');
        alertText.innerText = 'Müdahale Gerekli';
        alertText.classList.add('text-red-400');
    } else {
        alertEl.classList.add('text-brand-accent');
        alertEl.classList.remove('text-red-500');
        alertText.innerText = 'Normal';
        alertText.classList.remove('text-red-400');
    }
}

// Add activity feed entry
function addActivityLog(message, isDanger = false) {
    const feed = document.getElementById('activity-feed');
    const time = new Date().toLocaleTimeString([], {hour: '2-digit', minute:'2-digit', second:'2-digit'});
    
    const div = document.createElement('div');
    div.className = `p-3 rounded-lg border-l-4 ${isDanger ? 'bg-red-900/20 border-red-500' : 'bg-brand-900 border-brand-accent'} text-sm flex flex-col gap-1 transition-all`;
    div.innerHTML = `
        <span class="text-[10px] text-slate-500 font-bold">${time}</span>
        <span class="${isDanger ? 'text-red-200' : 'text-slate-300'}">${message}</span>
    `;
    
    feed.insertBefore(div, feed.firstChild);
    
    // Keep only last 10 logs
    if (feed.children.length > 10) {
        feed.removeChild(feed.lastChild);
    }
}

// Simulate real-time movement
setInterval(() => {
    teams.forEach(team => {
        // Randomly move them a tiny bit to simulate driving
        team.lat += (Math.random() - 0.5) * 0.05;
        team.lng += (Math.random() - 0.5) * 0.05;
        markers[team.id].setLatLng([team.lat, team.lng]);
    });
    
    // Simulate routing data increment
    if (Math.random() > 0.7) {
        totalRoutes += 1;
        updateStats();
    }
}, 3000);

// Expose emergency simulator to global scope for the button
window.simulateEmergency = function() {
    const randomTeam = teams[Math.floor(Math.random() * teams.length)];
    
    if (randomTeam.status === 'normal') {
        randomTeam.status = 'danger';
        markers[randomTeam.id].setIcon(createIcon('danger'));
        alertCount++;
        addActivityLog(`🚨 Ekip ${randomTeam.id} acil durum bildirdi! Konum: ${randomTeam.lat.toFixed(2)}, ${randomTeam.lng.toFixed(2)}`, true);
        
        // Pan map to emergency
        map.flyTo([randomTeam.lat, randomTeam.lng], 10, { animate: true, duration: 1.5 });
    } else {
        randomTeam.status = 'normal';
        markers[randomTeam.id].setIcon(createIcon('normal'));
        alertCount--;
        addActivityLog(`✅ Ekip ${randomTeam.id} durumu normale döndü.`);
    }
    updateStats();
};

// Initial calls
updateStats();
addActivityLog('Sistem başlatıldı, harita yüklendi.');
addActivityLog('5 ekip sahada izleniyor.');
