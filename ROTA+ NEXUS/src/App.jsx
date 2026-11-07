import React, { useState, useEffect, useCallback, useRef, useMemo } from 'react';
import Header from './components/Header';
import TacticalMap from './components/TacticalMap';
import OperationsPanel from './components/OperationsPanel';
import TacticalCockpit from './components/TacticalCockpit';
import TacticalLogConsole from './components/TacticalLogConsole';
import SosAlertBanner from './components/SosAlertBanner';
import UavThermalOverlay from './components/UavThermalOverlay';
import MissionBriefingModal from './components/MissionBriefingModal';
import TimelineReplayBar from './components/TimelineReplayBar';
import DispatchMissionLog, { INITIAL_TEAMS, INITIAL_STORYLINE } from './components/DispatchMissionLog';
import { subscribeToFirebaseUsers } from './firebase';
import { soundFx } from './audio';
import { 
  analyzeLocation, 
  checkHazardZoneProximity, 
  DEFAULT_HAZARD_ZONES, 
  calculateSmartSearchCone,
  calculateDistanceMeters,
  calculateEtaMinutes
} from './utils/geoAnalysis';

export default function App() {
  const [rawUsers, setRawUsers] = useState([]); // 100% Real Users from Firebase
  const [testSosIds, setTestSosIds] = useState(new Set()); // Instant in-app SOS tests
  const [dismissedSosIds, setDismissedSosIds] = useState(new Set());
  const [selectedUserId, setSelectedUserId] = useState(null);
  const [targetCoords, setTargetCoords] = useState([38.43, 27.18]); // İzmir Default Center
  const [activeLayer, setActiveLayer] = useState('TOPO_ESRI');
  const [isMuted, setIsMuted] = useState(true); // Default muted so no screaming on load
  const [dbStatus, setDbStatus] = useState({ status: 'CONNECTING', message: 'Firebase veritabanı bağlanıyor...' });
  const [logs, setLogs] = useState([
    'ROTA+ NEXUS OPERASYON KOMUTA MERKEZİ AKTİF',
    'CANLI VERİ ENTEGRASYON VE TELEMETRİ BAĞLANTISI DEVREDE',
    'FİREBASE rotaplus-cd84d CANLI DİNLENİYOR...',
  ]);

  // NEW FEATURE STATES (1, 2, 4, 5, 7)
  const [uavTargetUser, setUavTargetUser] = useState(null); // Feature 1: UAV Drone Target
  const [uavOrbitAngle, setUavOrbitAngle] = useState(0); // Synchronized Drone Orbit Angle
  const [briefingUser, setBriefingUser] = useState(null); // Feature 2: A4 Incident Briefing Modal
  const [playbackProgress, setPlaybackProgress] = useState(1.0); // Feature 7: Timeline Scrubber (1.0 = LIVE)
  const [isPlayingTimeline, setIsPlayingTimeline] = useState(false); // Feature 7: Timeline Play/Pause
  const [playbackSpeed, setPlaybackSpeed] = useState(1); // Feature 7: 1x, 2x, 5x, 10x

  // DISPATCH MISSION LOG & SMART SEARCH CONE STATES
  const [isDispatchLogOpen, setIsDispatchLogOpen] = useState(false);
  const [teams, setTeams] = useState(INITIAL_TEAMS);
  const [storyline, setStoryline] = useState(INITIAL_STORYLINE);
  const [directingTeamId, setDirectingTeamId] = useState(null);
  const [smartConeParams, setSmartConeParams] = useState({
    avgSpeedKmh: 3.8,
    headingDeg: 65,
    walkHours: 1.5,
    showCone: true
  });

  // Animate UAV flight orbit smoothly
  useEffect(() => {
    if (!uavTargetUser) return;
    const interval = setInterval(() => {
      setUavOrbitAngle((prev) => (prev + 1.2) % 360);
    }, 70);
    return () => clearInterval(interval);
  }, [uavTargetUser]);

  const prevDbStatusRef = useRef(null);
  const alertedBreachesRef = useRef(new Set());

  const addLog = useCallback((msg) => {
    const timeStr = new Date().toLocaleTimeString('tr-TR');
    setLogs((prev) => [...prev.slice(-45), `[${timeStr}] ${msg}`]);
  }, []);

  // 1. FIREBASE REAL-TIME SUBSCRIPTION
  useEffect(() => {
    const unsubscribe = subscribeToFirebaseUsers(
      (realUsers) => {
        setRawUsers(realUsers);
      },
      (statusObj) => {
        setDbStatus(statusObj);
        if (prevDbStatusRef.current !== statusObj.status) {
          prevDbStatusRef.current = statusObj.status;
          if (statusObj.status === 'LIVE') {
            addLog(`SİSTEM: Firebase canlı veri senkronizasyonu aktif.`);
          } else if (statusObj.status === 'ERROR') {
            addLog(`HATA: ${statusObj.message}`);
          }
        }
      },
      (newSosUser) => {
        addLog(`🚨 CANLI SOS SİNYALİ ALINDI: ${newSosUser.name} acil yardım butonuna bastı!`);
        if (newSosUser.hasCoords && newSosUser.coords) {
          setTargetCoords({ coords: newSosUser.coords, zoom: 16, timestamp: Date.now() });
        }
        setSelectedUserId(newSosUser.id);
        if (!isMuted) {
          soundFx.playSosBeep();
        }
      }
    );

    return () => unsubscribe();
  }, [addLog, isMuted]);

  // Compute users with local test overrides
  const users = useMemo(() => {
    return rawUsers.map((u) => {
      const isTestSos = testSosIds.has(u.id);
      const isFresh = (u.isFreshSos || isTestSos) && !dismissedSosIds.has(u.id);
      return {
        ...u,
        isTestSos,
        isFreshSos: isFresh,
      };
    });
  }, [rawUsers, testSosIds, dismissedSosIds]);

  // Derive selectedUser
  const selectedUser = useMemo(() => {
    if (!selectedUserId) return null;
    return users.find((u) => u.id === selectedUserId) || null;
  }, [users, selectedUserId]);

  // Filter active fresh SOS calls
  const activeSosUsers = useMemo(() => users.filter((u) => u.isFreshSos), [users]);
  const archiveSosUsers = useMemo(() => users.filter((u) => u.isArchiveSos && !u.isFreshSos), [users]);
  const mappedCount = useMemo(() => users.filter((u) => u.hasCoords).length, [users]);

  // Audio Siren Management
  useEffect(() => {
    if (!isMuted && activeSosUsers.length > 0) {
      soundFx.startSosAlarm();
    } else {
      soundFx.stopSosAlarm();
    }
  }, [activeSosUsers.length, isMuted]);

  // FEATURE 4: GEOFENCING PROXIMITY SCANNER
  useEffect(() => {
    if (users.length === 0) return;
    for (const u of users) {
      if (!u.hasCoords) continue;
      const breaches = checkHazardZoneProximity(u, DEFAULT_HAZARD_ZONES);
      for (const b of breaches) {
        const breachKey = `${u.id}-${b.zone.id}-${b.isInside ? 'INSIDE' : 'WARNING'}`;
        if (!alertedBreachesRef.current.has(breachKey)) {
          alertedBreachesRef.current.add(breachKey);
          addLog(b.message);
          if (b.isInside && !isMuted) {
            soundFx.playHazardAlert();
          }
        }
      }
    }
  }, [users, addLog, isMuted]);

  // FEATURE 7: 24-HOUR TIMELINE SCRUBBER TICKER
  useEffect(() => {
    if (!isPlayingTimeline) return;

    const interval = setInterval(() => {
      setPlaybackProgress((prev) => {
        const step = 0.003 * playbackSpeed;
        const next = prev + step;
        if (next >= 1.0) {
          setIsPlayingTimeline(false);
          addLog('⏱️ ZAMAN TÜNELİ: Güncel canlı zamana ulaşıldı.');
          return 1.0;
        }
        return next;
      });
    }, 100);

    return () => clearInterval(interval);
  }, [isPlayingTimeline, playbackSpeed, addLog]);

  // Dismiss / Silence an active SOS banner
  const handleDismissSos = (userId) => {
    setDismissedSosIds((prev) => {
      const next = new Set(prev);
      next.add(userId);
      return next;
    });
    setTestSosIds((prev) => {
      const next = new Set(prev);
      next.delete(userId);
      return next;
    });
    const target = users.find((u) => u.id === userId);
    addLog(`BİLDİRİM: ${target ? target.name : userId} için acil durum alarmı onaylandı ve söndürüldü.`);
  };

  // Commander can manually test SOS on any field user
  const handleToggleUserTestSos = (userId) => {
    const target = users.find((u) => u.id === userId);
    const targetName = target ? target.name : userId;

    if (testSosIds.has(userId) || (target && target.isFreshSos)) {
      setTestSosIds((prev) => {
        const next = new Set(prev);
        next.delete(userId);
        return next;
      });
      setDismissedSosIds((prev) => {
        const next = new Set(prev);
        next.add(userId);
        return next;
      });
      addLog(`✅ ACİL DURUM SONLANDIRILDI: ${targetName} durumu normale döndürüldü.`);
    } else {
      setDismissedSosIds((prev) => {
        const next = new Set(prev);
        next.delete(userId);
        return next;
      });
      setTestSosIds((prev) => {
        const next = new Set(prev);
        next.add(userId);
        return next;
      });
      if (target && target.hasCoords && target.coords) {
        setTargetCoords({ coords: target.coords, zoom: 16, timestamp: Date.now() });
        setSelectedUserId(target.id);
      }
      if (!isMuted) {
        soundFx.playSosBeep();
      }
      addLog(`🚨 TEST SOS ÇAĞRISI BAŞLATILDI: ${targetName} için canlı acil alarm tetiklendi!`);
    }
  };

  // Quick Sector Jumpers
  const handleJumpSector = (coords, zoom = 12) => {
    setTargetCoords({ coords, zoom, timestamp: Date.now() });
    soundFx.playSelect();
    addLog(`HEDEF SEKTÖR: ${coords[0].toFixed(2)}°N, ${coords[1].toFixed(2)}°E (${zoom}x) odaklandı.`);
  };

  const handleCenterSos = () => {
    const target = activeSosUsers.find((u) => u.hasCoords) || users.find((u) => u.hasCoords);
    if (target) {
      setTargetCoords({ coords: target.coords, zoom: 16, timestamp: Date.now() });
      setSelectedUserId(target.id);
      soundFx.playTargetLock();
      addLog(`HEDEF KİLİDİ: ${target.name} acil konumuna odaklanıldı.`);
    }
  };

  const handleSelectUser = (user) => {
    if (!user) {
      setSelectedUserId(null);
      return;
    }
    setSelectedUserId(user.id);
    if (user.hasCoords && user.coords) {
      setTargetCoords({ coords: user.coords, zoom: 15, timestamp: Date.now() });
    }
    soundFx.playTargetLock();
    const locInfo = analyzeLocation(user, users);
    addLog(`HEDEF KİLİDİ: ${user.name} kokpite bağlandı [Mevki: ${locInfo.sectorName}]`);
  };

  // Launch UAV Reconnaissance (FEATURE 1)
  const handleLaunchUav = (targetUser) => {
    setUavTargetUser(targetUser);
    if (targetUser.hasCoords && targetUser.coords) {
      setTargetCoords({ coords: targetUser.coords, zoom: 15, timestamp: Date.now() });
    }
    addLog(`🛰️ İHA GÖREVİ: BAYRAKTAR SAR-1 ${targetUser.name} üzerine keşif yörüngesine girdi.`);
  };

  // Open Mission Briefing Modal (FEATURE 2)
  const handleOpenBriefing = (user) => {
    setBriefingUser(user);
    addLog(`📄 DÖKÜMAN: ${user.name} için resmi görev emri brifingi hazırlandı.`);
  };

  // TEAM DISPATCH & DIRECTING HANDLERS
  const handleAddTeam = (newTeam) => {
    setTeams((prev) => [...prev, newTeam]);
    addLog(`🛡️ YENİ TİM SEVK EDİLDİ: ${newTeam.name} (${newTeam.leader}) sahaya girdi.`);
    soundFx.playSuccess();
  };

  const handleRemoveTeam = (teamId) => {
    const targetTeam = teams.find((t) => t.id === teamId);
    setTeams((prev) => prev.filter((t) => t.id !== teamId));
    if (directingTeamId === teamId) setDirectingTeamId(null);
    if (targetTeam) {
      addLog(`🛡️ TİM GÖREVDEN ÇEKİLDİ: ${targetTeam.name} operasyondan ayrıldı.`);
    }
    soundFx.playSelect();
  };

  const handleUpdateTeamCoords = (teamId, coords) => {
    setTeams((prev) =>
      prev.map((t) => {
        if (t.id !== teamId) return t;
        return { ...t, coords };
      })
    );
    const targetTeam = teams.find((t) => t.id === teamId);
    if (targetTeam) {
      addLog(`📍 MEVKİ GÜNCELLENDİ: ${targetTeam.shortName} yeni konuma taşındı [${coords[0].toFixed(4)}, ${coords[1].toFixed(4)}].`);
    }
  };

  const handleDirectTeam = (teamId, destCoords) => {
    if (!teamId || !destCoords) return;
    setTeams((prev) =>
      prev.map((t) => {
        if (t.id !== teamId) return t;
        return {
          ...t,
          targetCoords: destCoords,
          status: 'İNTİKALDE'
        };
      })
    );
    const targetTeam = teams.find((t) => t.id === teamId);
    setDirectingTeamId(null);
    if (targetTeam) {
      const dist = calculateDistanceMeters(targetTeam.coords[0], targetTeam.coords[1], destCoords[0], destCoords[1]);
      const eta = calculateEtaMinutes(dist, 4.5);
      addLog(`🎯 İNTİKAL EMRİ: ${targetTeam.shortName} hedefe yönlendirildi (${dist}m, ~${eta}dk).`);
    }
    soundFx.playTargetLock();
  };

  const handleDispatchToCasualty = (teamId) => {
    if (!focalCasualty || !focalCasualty.coords) {
      addLog(`UYARI: Haritada aktif kazazede konumu bulunamadı.`);
      return;
    }
    handleDirectTeam(teamId, focalCasualty.coords);
  };

  const handleCompleteTransit = (teamId) => {
    setTeams((prev) =>
      prev.map((t) => {
        if (t.id !== teamId) return t;
        const newCoords = t.targetCoords || t.coords;
        return {
          ...t,
          coords: newCoords,
          targetCoords: null,
          status: 'SEKTÖRDE'
        };
      })
    );
    const targetTeam = teams.find((t) => t.id === teamId);
    if (targetTeam) {
      addLog(`✅ SEKTÖRE VARIŞ: ${targetTeam.shortName} hedef mevkiye intikalini tamamladı.`);
    }
    soundFx.playSuccess();
  };

  // Smart Search Cone calculation for focal casualty / user
  const focalCasualty = selectedUser || activeSosUsers[0] || (users.find(u => u.hasCoords) || null);
  const smartSearchCone = useMemo(() => {
    if (!focalCasualty || !focalCasualty.hasCoords) return null;
    return calculateSmartSearchCone(focalCasualty, smartConeParams);
  }, [focalCasualty, smartConeParams]);

  return (
    <div className="relative w-screen h-screen bg-[#02040A] overflow-hidden flex flex-col select-none font-tactical">
      
      {/* TACTICAL CRT SCANLINE OVERLAY */}
      <div className="absolute inset-0 tactical-scanline z-50 pointer-events-none" />

      {/* TOP COMMAND HEADER */}
      <Header
        users={users}
        freshSosCount={activeSosUsers.length}
        archiveSosCount={archiveSosUsers.length}
        dbStatus={dbStatus}
        isMuted={isMuted}
        onToggleMute={() => {
          const next = !isMuted;
          setIsMuted(next);
          soundFx.setMuted(next);
        }}
        onCenterSos={handleCenterSos}
        onJumpSector={handleJumpSector}
        activeLayer={activeLayer}
        onSelectLayer={(layerId) => {
          setActiveLayer(layerId);
          soundFx.playSelect();
        }}
        onOpenDispatchLog={() => setIsDispatchLogOpen(true)}
        dispatchedTeamsCount={teams.length}
      />

      {/* MAIN VIEWPORT LAYOUT: DOCKED LEFT + CENTER (MAP + REPLAY + LOGS) + DOCKED RIGHT */}
      <div className="relative flex-1 w-full h-[calc(100vh-48px)] flex overflow-hidden">
        
        {/* 1. LEFT DOCKED PANEL: SAHA KADROSU & EKİP */}
        <OperationsPanel
          users={users}
          selectedUser={selectedUser}
          onSelectUser={handleSelectUser}
          onCenterUser={(coords) => setTargetCoords({ coords, zoom: 15, timestamp: Date.now() })}
          onToggleUserTestSos={handleToggleUserTestSos}
        />

        {/* 2. CENTER AREA: MAP + TIMELINE REPLAY + LOG CONSOLE */}
        <div className="relative flex-1 h-full flex flex-col overflow-hidden">
          
          {/* Map Container */}
          <div className="relative flex-1 w-full h-full overflow-hidden">
            <TacticalMap
              users={users}
              selectedUser={selectedUser}
              onSelectUser={handleSelectUser}
              targetCoords={targetCoords}
              activeSosUser={activeSosUsers[0] || null}
              activeLayer={activeLayer}
              uavTargetUser={uavTargetUser}
              uavOrbitAngle={uavOrbitAngle}
              hazardZones={DEFAULT_HAZARD_ZONES}
              playbackProgress={playbackProgress}
              onCenterTarget={(coords, zoom = 15) => setTargetCoords({ coords, zoom, timestamp: Date.now() })}
              smartSearchCone={smartSearchCone}
              showSmartCone={smartConeParams.showCone}
              dispatchedTeams={teams}
              showDispatchedTeams={true}
              incidentStoryline={storyline}
              showStoryline={true}
              directingTeamId={directingTeamId}
              onStartDirecting={(id) => setDirectingTeamId(id)}
              onMapDirectTeam={(coords) => handleDirectTeam(directingTeamId, coords)}
              onCancelDirecting={() => setDirectingTeamId(null)}
              onUpdateTeamCoords={handleUpdateTeamCoords}
              onRemoveTeam={handleRemoveTeam}
              onDispatchToCasualty={handleDispatchToCasualty}
              onCompleteTransit={handleCompleteTransit}
              onOpenAddTeam={() => setIsDispatchLogOpen(true)}
            />

            {/* FLOATING HIGH PRIORITY SOS ALERT BANNER */}
            <SosAlertBanner
              sosUsers={activeSosUsers}
              onCenterTarget={(coords, zoom = 15) => setTargetCoords({ coords, zoom, timestamp: Date.now() })}
              onDismissSos={handleDismissSos}
            />

            {/* FEATURE 1: UAV FLIR THERMAL OVERLAY VIEWFINDER */}
            {uavTargetUser && (
              <UavThermalOverlay
                targetUser={uavTargetUser}
                orbitAngle={uavOrbitAngle}
                onClose={() => setUavTargetUser(null)}
              />
            )}
          </div>

          {/* FEATURE 7: 24-HOUR TIMELINE SCRUBBER & PLAYBACK CONTROLLER */}
          <TimelineReplayBar
            progress={playbackProgress}
            onChangeProgress={(val) => {
              setPlaybackProgress(val);
              if (isPlayingTimeline) setIsPlayingTimeline(false);
            }}
            isPlaying={isPlayingTimeline}
            onTogglePlay={() => setIsPlayingTimeline(!isPlayingTimeline)}
            speed={playbackSpeed}
            onChangeSpeed={(spd) => setPlaybackSpeed(spd)}
            onResetLive={() => {
              setPlaybackProgress(1.0);
              setIsPlayingTimeline(false);
            }}
          />

          {/* DOCKED BOTTOM LOG CONSOLE */}
          <TacticalLogConsole logs={logs} />

        </div>

        {/* 3. RIGHT DOCKED PANEL: KOKPİT, MEVKİİ, METEOROLOJİ, HAYATTA KALMA SAYACI */}
        <TacticalCockpit
          user={selectedUser}
          allUsers={users}
          onClose={() => setSelectedUserId(null)}
          onCenterTarget={(coords, zoom = 15) => setTargetCoords({ coords, zoom, timestamp: Date.now() })}
          onSelectUser={handleSelectUser}
          onToggleUserTestSos={handleToggleUserTestSos}
          onLaunchUav={handleLaunchUav}
          onOpenBriefing={handleOpenBriefing}
          onOpenDispatchLog={() => setIsDispatchLogOpen(true)}
          smartSearchCone={smartSearchCone}
          coneParams={smartConeParams}
          onUpdateConeParams={setSmartConeParams}
          allUsersCount={users.length}
          mappedCount={mappedCount}
          freshSosCount={activeSosUsers.length}
        />

      </div>

      {/* FEATURE 2: OFFICIAL PRINTABLE A4 INCIDENT BRIEFING MODAL */}
      {briefingUser && (
        <MissionBriefingModal
          user={briefingUser}
          allUsers={users}
          onClose={() => setBriefingUser(null)}
        />
      )}

      {/* FEATURE: GÖREV GÜNLÜĞÜ & EKİP/EKİPMAN SEVK MODALI & OLAY ÖRGÜSÜ */}
      <DispatchMissionLog
        isOpen={isDispatchLogOpen}
        onClose={() => setIsDispatchLogOpen(false)}
        selectedUser={selectedUser || activeSosUsers[0]}
        teams={teams}
        onUpdateTeams={setTeams}
        onAddTeam={handleAddTeam}
        onRemoveTeam={handleRemoveTeam}
        onDirectTeam={handleDirectTeam}
        onDispatchToCasualty={handleDispatchToCasualty}
        onStartDirectingOnMap={(id) => {
          setDirectingTeamId(id);
          setIsDispatchLogOpen(false);
        }}
        storyline={storyline}
        onUpdateStoryline={setStoryline}
        onCenterMap={(coords, zoom = 16) => setTargetCoords({ coords, zoom, timestamp: Date.now() })}
      />

    </div>
  );
}
