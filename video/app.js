document.addEventListener('DOMContentLoaded', () => {
    
    // UI Elements
    const ideaInput = document.getElementById('idea-input');
    const styleCards = document.querySelectorAll('.style-card');
    const generateBtn = document.getElementById('generate-btn');
    const enhanceBtn = document.getElementById('enhance-btn');
    
    const homeScreen = document.getElementById('home-screen');
    const generationScreen = document.getElementById('generation-screen');
    const previewScreen = document.getElementById('preview-screen');
    
    const aiExplanation = document.getElementById('ai-explanation');
    const resMode = document.getElementById('res-mode');

    let selectedStyle = 'Realistic';

    // Style Selection
    styleCards.forEach(card => {
        card.addEventListener('click', () => {
            styleCards.forEach(c => c.classList.remove('active'));
            card.classList.add('active');
            selectedStyle = card.dataset.style;
        });
    });

    // AI Idea Enhancer
    enhanceBtn.addEventListener('click', () => {
        const currentText = ideaInput.value.trim();
        if (currentText.length < 5) {
            ideaInput.value = "Yağmurlu bir gecede İstanbul sokaklarında yürüyen bir adam. Sinematik, karanlık ve gerçekçi.";
        } else {
            ideaInput.value = currentText + " Drone kamera ile geniş açıdan takip ediliyor, atmosferik ışıklandırma ve yüksek kontrastlı renk paleti.";
        }
        ideaInput.style.backgroundColor = "rgba(108, 92, 231, 0.1)";
        setTimeout(() => {
            ideaInput.style.backgroundColor = "transparent";
        }, 500);
    });

    // Generation Flow
    generateBtn.addEventListener('click', () => {
        if (!ideaInput.value.trim()) {
            alert("Lütfen bir fikir girin.");
            return;
        }
        
        // Update Final preview screen details
        resMode.textContent = selectedStyle;

        // Switch to Generation Screen
        switchScreen(generationScreen);
        startGenerationProcess();
    });

    function switchScreen(screen) {
        homeScreen.classList.remove('active');
        generationScreen.classList.remove('active');
        previewScreen.classList.remove('active');
        
        screen.classList.add('active');
    }

    async function startGenerationProcess() {
        const steps = [
            { id: 'step-1', text: 'Analyzing idea with NVIDIA Kimi-k3...' },
            { id: 'step-2', text: 'Building story & camera angles...' },
            { id: 'step-3', text: 'Selecting visual style...' },
            { id: 'step-4', text: 'Designing cinematography...' },
            { id: 'step-5', text: 'Creating storyboard...' },
            { id: 'step-6', text: 'Optimizing prompt...' },
            { id: 'step-7', text: 'Generating visual frame...' },
            { id: 'step-8', text: 'Finalizing Project...' }
        ];

        // Reset all steps to pending
        steps.forEach(s => {
            const el = document.getElementById(s.id);
            if(el) {
                el.className = 'status-item pending';
                el.innerHTML = '○ ' + s.text;
            }
        });

        // Set first step active
        document.getElementById('step-1').classList.add('active');
        document.getElementById('step-1').classList.remove('pending');
        aiExplanation.textContent = "Connecting to NVIDIA Kimi-k3 API...";

        try {
            const response = await fetch('http://127.0.0.1:5000/api/director', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    idea: ideaInput.value,
                    style: selectedStyle
                })
            });

            if (!response.ok) {
                const errData = await response.json();
                throw new Error(errData.error || "API Request failed");
            }

            const data = await response.json();
            
            // Fast forward UI simulation
            let i = 1;
            const interval = setInterval(() => {
                if(i < steps.length) {
                    document.getElementById(steps[i-1].id).className = 'status-item done';
                    document.getElementById(steps[i-1].id).innerHTML = '✓ ' + steps[i-1].text;
                    
                    document.getElementById(steps[i].id).className = 'status-item active';
                    document.getElementById(steps[i].id).innerHTML = '● ' + steps[i].text;
                    i++;
                } else {
                    clearInterval(interval);
                    document.getElementById(steps[steps.length-1].id).className = 'status-item done';
                    
                    // Update Preview Screen with Real Data
                    resMode.textContent = data.mode || selectedStyle;
                    
                    // The backend generates a real high-res image based on Kimi-k3's prompt. 
                    // Since we don't have a video endpoint, we will display this image in the player.
                    const playerContainer = document.querySelector('.video-player');
                    playerContainer.innerHTML = `<img src="${data.image_url}" style="width:100%; height:100%; object-fit:cover; border-radius: 8px 8px 0 0;" alt="Generated Frame">`;
                    
                    // Show Prompt in Details
                    const detailGrid = document.querySelector('.detail-grid');
                    detailGrid.innerHTML = `
                        <div class="detail-item">
                            <span class="label">Mode</span>
                            <span class="value">${data.mode || selectedStyle}</span>
                        </div>
                        <div class="detail-item">
                            <span class="label">Camera</span>
                            <span class="value">${data.camera || "Auto"}</span>
                        </div>
                        <div class="detail-item">
                            <span class="label">Lighting</span>
                            <span class="value">${data.lighting || "Auto"}</span>
                        </div>
                    `;

                    switchScreen(previewScreen);
                }
            }, 500);

        } catch (error) {
            console.error("Error:", error);
            // Try to extract exact error message if possible
            let errorMsg = "Gerçek API'ye bağlanırken hata oluştu. (Sunucu kapalı olabilir veya API reddetti)";
            try {
                if (error.message) {
                    errorMsg += "\nDetay: " + error.message;
                }
            } catch(e) {}
            alert(errorMsg + "\nLütfen server.py'nin çalıştığı siyah ekrana (konsola) bakıp kırmızı bir hata yazısı olup olmadığını kontrol edin.");
            switchScreen(homeScreen);
        }
    }

    // Export Reset App for global scope to use in onclick
    window.resetApp = function() {
        // Reset status items
        const statusItems = document.querySelectorAll('.status-item');
        statusItems.forEach(item => {
            item.className = 'status-item pending';
            item.innerHTML = '○ ' + item.innerText.substring(2);
        });
        
        // Reset video player
        const resultVideo = document.getElementById('result-video');
        const videoPlaceholder = document.getElementById('video-placeholder');
        if (resultVideo) {
            resultVideo.pause();
            resultVideo.currentTime = 0;
            resultVideo.style.display = 'none';
        }
        if (videoPlaceholder) {
            videoPlaceholder.style.display = 'block';
        }

        switchScreen(homeScreen);
    }
});
