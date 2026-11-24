import React, { useState, useEffect, useRef, useMemo } from 'react';
import {
  Compass,
  Crosshair,
  Eye,
  Zap,
  Radar,
  Grid,
  Navigation2,
  Route,
  ShieldAlert,
  Shield,
  Plus,
  Trash2,
  X
} from 'lucide-react';
import { soundFx } from '../audio';
import {
  getSignalFreshness,
  getUserBreadcrumbTrail,
  generateTacticalSearchGrid,
  analyzeLocation,
  calculateSearchZoneProbability,
  DEFAULT_HAZARD_ZONES,
  interpolateUserTrack,
  calculateDistanceMeters,
  calculateEtaMinutes
} from '../utils/terrainMath';

const MAP_LAYERS = {
  TOPO_ESRI: {
    id: 'TOPO_ESRI',
    name: 'ESRI Topo & Arazi',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 19
  },
  OPENTOPO: {
    id: 'OPENTOPO',
    name: 'OpenTopo (İzolips & Dağ)',
    url: 'https://a.tile.opentopomap.org/{z}/{x}/{y}.png',
    maxZoom: 17
  },
  SATELLITE_HYBRID: {
    id: 'SATELLITE_HYBRID',
    name: 'Uydu Hibrit',
    url: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    overlayUrl: 'https://services.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
    maxZoom: 19
  },
  TACTICAL_DARK: {
    id: 'TACTICAL_DARK',
    name: 'Taktik Karanlık Gece',
    url: 'https://a.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png',
    maxZoom: 19
  }
};

function zoomToHeight(zoom = 14) {
  const table = {
    6: 1400000,
    8: 350000,
    10: 95000,
    12: 28000,
    13: 16000,
    14: 9500,
    15: 5500,
    16: 3200,
    17: 1800,
    18: 1000
  };
  return table[zoom] || Math.max(1200, Math.round(45000000 / Math.pow(2, zoom)));
}

function makeUserSvgUri(user, isSelected) {
  const isEmergency = Boolean(user.isFreshSos || user.isTestSos);
  const isArchive = Boolean(user.isArchiveSos && !isEmergency);
  const signal = getSignalFreshness(user);
  const isLostSignal = signal.isLost && !isEmergency;
  const color = isEmergency
    ? '#EF4444'
    : isSelected
    ? '#00E5FF'
    : isLostSignal
    ? '#F59E0B'
    : isArchive
    ? '#D97706'
    : user.role === 'KOMUTAN'
    ? '#FF8A00'
    : '#FF4D26';
  const initials = (user.initials || 'RP').slice(0, 3);
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="46" height="46" viewBox="0 0 46 46">
    <rect x="4" y="4" width="38" height="38" fill="#02050D" stroke="${color}" stroke-width="${isSelected ? 3 : 2}" ${isLostSignal ? 'stroke-dasharray="4 3"' : ''}/>
    ${isEmergency ? `<circle cx="23" cy="23" r="21" fill="none" stroke="#EF4444" stroke-width="2" opacity="0.8"/>` : ''}
    <text x="23" y="28" text-anchor="middle" fill="${color}" font-family="monospace" font-size="13" font-weight="800">${initials}</text>
  </svg>`;
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}

function makeTeamSvgUri(team) {
  const color = team.color || '#00E5FF';
  const label = (team.shortName || 'SAR').slice(0, 4).toUpperCase();
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="44" height="44" viewBox="0 0 44 44">
    <polygon points="22,3 41,22 22,41 3,22" fill="#02050D" stroke="${color}" stroke-width="2.5"/>
    <text x="22" y="26" text-anchor="middle" fill="#F8FAFC" font-family="monospace" font-size="10" font-weight="800">${label}</text>
  </svg>`;
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}

function makeUavSvgUri(angleDeg) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="38" height="38" viewBox="0 0 38 38">
    <g transform="rotate(${angleDeg} 19 19)">
      <polygon points="19,3 25,18 35,23 23,25 19,35 15,25 3,23 13,18" fill="#00E5FF" stroke="#02050D" stroke-width="1.5"/>
    </g>
  </svg>`;
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}

function makeStepSvgUri(num) {
  const svg = `<svg xmlns="http://www.w3.org/2000/svg" width="28" height="28" viewBox="0 0 28 28">
    <circle cx="14" cy="14" r="12" fill="#02050D" stroke="#10B981" stroke-width="2"/>
    <text x="14" y="18" text-anchor="middle" fill="#34D399" font-family="monospace" font-size="11" font-weight="800">${num}</text>
  </svg>`;
  return 'data:image/svg+xml;charset=utf-8,' + encodeURIComponent(svg);
}

export default function TacticalMap({
  users = [],
  selectedUser = null,
  onSelectUser = () => {},
  targetCoords = null,
  activeSosUser = null,
  activeLayer = 'TOPO_ESRI',
  uavTargetUser = null,
  uavOrbitAngle = 0,
  hazardZones = DEFAULT_HAZARD_ZONES,
  playbackProgress = 1.0,
  onCenterTarget = () => {},
  smartSearchCone = null,
  showSmartCone = true,
  dispatchedTeams = [],
  showDispatchedTeams = true,
  incidentStoryline = [],
  showStoryline = true,
  directingTeamId = null,
  onStartDirecting = () => {},
  onMapDirectTeam = () => {},
  onCancelDirecting = () => {},
  onUpdateTeamCoords = () => {},
  onRemoveTeam = () => {},
  onDispatchToCasualty = () => {},
  onCompleteTransit = () => {},
  onOpenAddTeam = () => {}
}) {
  const containerRef = useRef(null);
  const viewerRef = useRef(null);
  const entitiesRef = useRef([]);
  const overlayLayerRef = useRef(null);
  const directingRef = useRef(null);
  const onMapDirectRef = useRef(onMapDirectTeam);

  const [mouseCoords, setMouseCoords] = useState([38.43, 27.18]);
  const [enableRadarEffect, setEnableRadarEffect] = useState(true);
  const [showBreadcrumbs, setShowBreadcrumbs] = useState(true);
  const [showSarVectors, setShowSarVectors] = useState(true);
  const [showSarGrid, setShowSarGrid] = useState(false);
  const [showHazards, setShowHazards] = useState(true);
  const [enableSmartCone, setEnableSmartCone] = useState(true);
  const [enableTeams, setEnableTeams] = useState(true);
  const [enableStoryline, setEnableStoryline] = useState(true);
  const [popupItem, setPopupItem] = useState(null);

  directingRef.current = directingTeamId;
  onMapDirectRef.current = onMapDirectTeam;

  const directingTeam = useMemo(
    () => dispatchedTeams.find((t) => t.id === directingTeamId) || null,
    [dispatchedTeams, directingTeamId]
  );

  const mappedUsers = useMemo(() => users.filter((u) => u.hasCoords && u.coords), [users]);
  const focalUser = selectedUser || activeSosUser || null;

  const analysis = useMemo(() => {
    if (!focalUser) return null;
    return analyzeLocation(focalUser, users);
  }, [focalUser, users]);

  const breadcrumbTrail = useMemo(() => {
    if (!focalUser || !showBreadcrumbs) return [];
    return getUserBreadcrumbTrail(focalUser);
  }, [focalUser, showBreadcrumbs]);

  const sarGrid = useMemo(() => generateTacticalSearchGrid(), []);

  const lkpProbability = useMemo(() => {
    if (!focalUser) return null;
    const signal = getSignalFreshness(focalUser);
    if (!signal.isLost) return null;
    return calculateSearchZoneProbability(focalUser);
  }, [focalUser]);

  const uavPosition = useMemo(() => {
    if (!uavTargetUser || !uavTargetUser.hasCoords) return null;
    const rad = (uavOrbitAngle * Math.PI) / 180;
    return [uavTargetUser.lat + 0.0055 * Math.cos(rad), uavTargetUser.lng + 0.0075 * Math.sin(rad)];
  }, [uavTargetUser, uavOrbitAngle]);

  const handleDirectSelect = (user) => {
    onSelectUser(user);
    if (user.hasCoords && user.coords) {
      onCenterTarget(user.coords, 15);
    }
    soundFx.playTargetLock();
  };

  // 1. Initialize CesiumJS 3D Globe Viewer once
  useEffect(() => {
    const Cesium = window.Cesium;
    if (!Cesium || !containerRef.current || viewerRef.current) return;

    const initCfg = MAP_LAYERS[activeLayer] || MAP_LAYERS.TOPO_ESRI;
    const baseProvider = new Cesium.UrlTemplateImageryProvider({
      url: initCfg.url,
      maximumLevel: initCfg.maxZoom || 19
    });

    const viewer = new Cesium.Viewer(containerRef.current, {
      baseLayer: new Cesium.ImageryLayer(baseProvider),
      baseLayerPicker: false,
      geocoder: false,
      homeButton: false,
      sceneModePicker: false,
      navigationHelpButton: false,
      animation: false,
      timeline: false,
      fullscreenButton: false,
      selectionIndicator: false,
      infoBox: false,
      skyBox: false,
      skyAtmosphere: new Cesium.SkyAtmosphere()
    });

    viewer.scene.backgroundColor = Cesium.Color.fromCssColorString('#02040A');
    viewer.scene.globe.baseColor = Cesium.Color.fromCssColorString('#02040A');
    viewer.scene.globe.enableLighting = false;

    viewer.camera.setView({
      destination: Cesium.Cartesian3.fromDegrees(27.18, 38.43, zoomToHeight(12)),
      orientation: {
        heading: 0.0,
        pitch: Cesium.Math.toRadians(-52),
        roll: 0.0
      }
    });

    const handler = new Cesium.ScreenSpaceEventHandler(viewer.scene.canvas);
    handler.setInputAction((movement) => {
      const cartesian = viewer.camera.pickEllipsoid(movement.endPosition, viewer.scene.globe.ellipsoid);
      if (cartesian) {
        const carto = Cesium.Cartographic.fromCartesian(cartesian);
        setMouseCoords([Cesium.Math.toDegrees(carto.latitude), Cesium.Math.toDegrees(carto.longitude)]);
      }
    }, Cesium.ScreenSpaceEventType.MOUSE_MOVE);

    handler.setInputAction((movement) => {
      if (directingRef.current && onMapDirectRef.current) {
        const cartesian = viewer.camera.pickEllipsoid(movement.position, viewer.scene.globe.ellipsoid);
        if (cartesian) {
          const carto = Cesium.Cartographic.fromCartesian(cartesian);
          onMapDirectRef.current([Cesium.Math.toDegrees(carto.latitude), Cesium.Math.toDegrees(carto.longitude)]);
          return;
        }
      }

      const picked = viewer.scene.pick(movement.position);
      if (Cesium.defined(picked) && picked.id && picked.id._nexusPayload) {
        const payload = picked.id._nexusPayload;
        setPopupItem(payload);
        if (payload.kind === 'user' && payload.user) {
          handleDirectSelect(payload.user);
        } else {
          soundFx.playSelect();
        }
      } else {
        setPopupItem(null);
      }
    }, Cesium.ScreenSpaceEventType.LEFT_CLICK);

    viewerRef.current = viewer;

    return () => {
      handler.destroy();
      if (!viewer.isDestroyed()) viewer.destroy();
      viewerRef.current = null;
    };
  }, []);

  // 2. Switch Base Layer when activeLayer changes
  useEffect(() => {
    const Cesium = window.Cesium;
    const viewer = viewerRef.current;
    if (!Cesium || !viewer || viewer.isDestroyed()) return;

    const cfg = MAP_LAYERS[activeLayer] || MAP_LAYERS.TOPO_ESRI;
    viewer.imageryLayers.removeAll(true);
    viewer.imageryLayers.addImageryProvider(
      new Cesium.UrlTemplateImageryProvider({ url: cfg.url, maximumLevel: cfg.maxZoom || 19 })
    );
    if (cfg.overlayUrl) {
      overlayLayerRef.current = viewer.imageryLayers.addImageryProvider(
        new Cesium.UrlTemplateImageryProvider({ url: cfg.overlayUrl, maximumLevel: 19 })
      );
    } else {
      overlayLayerRef.current = null;
    }
  }, [activeLayer]);

  // 3. Camera FlyTo when targetCoords updates
  useEffect(() => {
    const Cesium = window.Cesium;
    const viewer = viewerRef.current;
    if (!Cesium || !viewer || viewer.isDestroyed() || !targetCoords) return;

    const coords = Array.isArray(targetCoords) ? targetCoords : targetCoords.coords;
    const zoom = !Array.isArray(targetCoords) && targetCoords.zoom ? targetCoords.zoom : 14;
    if (coords && coords[0] && coords[1]) {
      viewer.camera.flyTo({
        destination: Cesium.Cartesian3.fromDegrees(coords[1], coords[0] - 0.015, zoomToHeight(zoom)),
        orientation: {
          heading: 0.0,
          pitch: Cesium.Math.toRadians(-48),
          roll: 0.0
        },
        duration: 1.2
      });
    }
  }, [targetCoords]);

  // 4. Render all 3D Entities onto CesiumJS Globe
  useEffect(() => {
    const Cesium = window.Cesium;
    const viewer = viewerRef.current;
    if (!Cesium || !viewer || viewer.isDestroyed()) return;

    entitiesRef.current.forEach((e) => viewer.entities.remove(e));
    entitiesRef.current = [];
    const addEnt = (opts, payload = null) => {
      const ent = viewer.entities.add(opts);
      if (payload) ent._nexusPayload = payload;
      entitiesRef.current.push(ent);
      return ent;
    };

    // Hazard Zones
    if (showHazards && hazardZones) {
      hazardZones.forEach((hz) => {
        if (!hz.polygon || hz.polygon.length < 3) return;
        const flat = hz.polygon.flatMap((p) => [p[1], p[0]]);
        const color = Cesium.Color.fromCssColorString(hz.color || '#EF4444');
        addEnt({
          polygon: {
            hierarchy: Cesium.Cartesian3.fromDegreesArray(flat),
            material: color.withAlpha(0.18),
            outline: true,
            outlineColor: color.withAlpha(0.85)
          }
        });
      });
    }

    // SAR Tactical Grid
    if (showSarGrid && sarGrid) {
      sarGrid.forEach((cell) => {
        if (!cell.bounds || cell.bounds.length < 3) return;
        const flat = cell.bounds.flatMap((p) => [p[1], p[0]]);
        addEnt({
          polygon: {
            hierarchy: Cesium.Cartesian3.fromDegreesArray(flat),
            material: Cesium.Color.CYAN.withAlpha(0.04),
            outline: true,
            outlineColor: Cesium.Color.CYAN.withAlpha(0.35)
          }
        });
      });
    }

    // Breadcrumb Trail
    if (showBreadcrumbs && breadcrumbTrail.length > 1) {
      const flat = breadcrumbTrail.flatMap((p) => [p[1], p[0], 15]);
      addEnt({
        polyline: {
          positions: Cesium.Cartesian3.fromDegreesArrayHeights(flat),
          width: 4,
          material: new Cesium.PolylineGlowMaterialProperty({
            glowPower: 0.25,
            color: Cesium.Color.fromCssColorString(focalUser?.isFreshSos ? '#EF4444' : '#FF8A00')
          })
        }
      });
    }

    // SAR Interception Vectors
    if (showSarVectors && focalUser && analysis?.nearestComrades) {
      analysis.nearestComrades.forEach((comrade) => {
        if (!comrade.coords) return;
        addEnt({
          polyline: {
            positions: Cesium.Cartesian3.fromDegreesArrayHeights([
              focalUser.lng, focalUser.lat, 25,
              comrade.lng, comrade.lat, 25
            ]),
            width: 2,
            material: new Cesium.PolylineDashMaterialProperty({
              color: Cesium.Color.fromCssColorString(focalUser.isFreshSos ? '#EF4444' : '#00E5FF')
            })
          }
        });
      });
    }

    // LKP Probability Search Circle
    if (lkpProbability && focalUser?.coords) {
      addEnt({
        position: Cesium.Cartesian3.fromDegrees(focalUser.lng, focalUser.lat),
        ellipse: {
          semiMajorAxis: lkpProbability.radiusMeters,
          semiMinorAxis: lkpProbability.radiusMeters,
          material: Cesium.Color.fromCssColorString('#F59E0B').withAlpha(0.1),
          outline: true,
          outlineColor: Cesium.Color.fromCssColorString('#F59E0B')
        }
      });
    }

    // UAV Drone Orbit + Sensor Beam
    if (uavPosition && uavTargetUser) {
      addEnt({
        position: Cesium.Cartesian3.fromDegrees(uavTargetUser.lng, uavTargetUser.lat),
        ellipse: {
          semiMajorAxis: 650,
          semiMinorAxis: 650,
          material: Cesium.Color.TRANSPARENT,
          outline: true,
          outlineColor: Cesium.Color.CYAN.withAlpha(0.6)
        }
      });
      addEnt({
        polyline: {
          positions: Cesium.Cartesian3.fromDegreesArrayHeights([
            uavPosition[1], uavPosition[0], 220,
            uavTargetUser.lng, uavTargetUser.lat, 20
          ]),
          width: 2,
          material: new Cesium.PolylineDashMaterialProperty({ color: Cesium.Color.CYAN })
        }
      });
      addEnt({
        position: Cesium.Cartesian3.fromDegrees(uavPosition[1], uavPosition[0], 220),
        billboard: {
          image: makeUavSvgUri(uavOrbitAngle + 90),
          width: 34,
          height: 34,
          disableDepthTestDistance: Number.POSITIVE_INFINITY
        }
      });
    }

    // Smart Search Cone
    if (showSmartCone && enableSmartCone && smartSearchCone) {
      if (smartSearchCone.conePolygon?.length >= 3) {
        addEnt({
          polygon: {
            hierarchy: Cesium.Cartesian3.fromDegreesArray(smartSearchCone.conePolygon.flatMap((p) => [p[1], p[0]])),
            material: Cesium.Color.fromCssColorString('#F59E0B').withAlpha(0.16),
            outline: true,
            outlineColor: Cesium.Color.fromCssColorString('#F59E0B')
          }
        });
      }
      if (smartSearchCone.corePolygon?.length >= 3) {
        addEnt({
          polygon: {
            hierarchy: Cesium.Cartesian3.fromDegreesArray(smartSearchCone.corePolygon.flatMap((p) => [p[1], p[0]])),
            material: Cesium.Color.fromCssColorString('#EF4444').withAlpha(0.24),
            outline: true,
            outlineColor: Cesium.Color.fromCssColorString('#EF4444')
          }
        });
      }
      if (smartSearchCone.lkp && smartSearchCone.apexPoint) {
        addEnt({
          polyline: {
            positions: Cesium.Cartesian3.fromDegreesArrayHeights([
              smartSearchCone.lkp[1], smartSearchCone.lkp[0], 20,
              smartSearchCone.apexPoint[1], smartSearchCone.apexPoint[0], 20
            ]),
            width: 3,
            material: Cesium.Color.fromCssColorString('#F59E0B')
          }
        });
      }
    }

    // Dispatched Rescue Teams
    if (showDispatchedTeams && enableTeams) {
      dispatchedTeams.forEach((team) => {
        const teamColor = Cesium.Color.fromCssColorString(team.color || '#00E5FF');
        addEnt({
          position: Cesium.Cartesian3.fromDegrees(team.coords[1], team.coords[0]),
          ellipse: {
            semiMajorAxis: 180,
            semiMinorAxis: 180,
            material: teamColor.withAlpha(0.1),
            outline: true,
            outlineColor: teamColor.withAlpha(0.7)
          }
        });
        addEnt(
          {
            position: Cesium.Cartesian3.fromDegrees(team.coords[1], team.coords[0], 25),
            billboard: {
              image: makeTeamSvgUri(team),
              width: 36,
              height: 36,
              disableDepthTestDistance: Number.POSITIVE_INFINITY
            },
            label: {
              text: team.shortName || team.name,
              font: '10px "Share Tech Mono", monospace',
              fillColor: teamColor,
              outlineColor: Cesium.Color.BLACK,
              outlineWidth: 3,
              style: Cesium.LabelStyle.FILL_AND_OUTLINE,
              pixelOffset: new Cesium.Cartesian2(0, 24),
              disableDepthTestDistance: Number.POSITIVE_INFINITY
            }
          },
          { kind: 'team', team }
        );

        if (team.targetCoords?.length === 2) {
          addEnt({
            polyline: {
              positions: Cesium.Cartesian3.fromDegreesArrayHeights([
                team.coords[1], team.coords[0], 25,
                team.targetCoords[1], team.targetCoords[0], 25
              ]),
              width: 3,
              material: new Cesium.PolylineDashMaterialProperty({ color: Cesium.Color.fromCssColorString('#F59E0B') })
            }
          });
          addEnt(
            {
              position: Cesium.Cartesian3.fromDegrees(team.targetCoords[1], team.targetCoords[0], 20),
              point: {
                pixelSize: 11,
                color: Cesium.Color.fromCssColorString('#F59E0B'),
                outlineColor: Cesium.Color.BLACK,
                outlineWidth: 2,
                disableDepthTestDistance: Number.POSITIVE_INFINITY
              }
            },
            { kind: 'teamTarget', team }
          );
        }
      });
    }

    // Incident Storyline
    if (showStoryline && enableStoryline && incidentStoryline?.length > 0) {
      const pts = incidentStoryline.filter((s) => s.coords);
      if (pts.length > 1) {
        addEnt({
          polyline: {
            positions: Cesium.Cartesian3.fromDegreesArrayHeights(pts.flatMap((s) => [s.coords[1], s.coords[0], 18])),
            width: 2,
            material: new Cesium.PolylineDashMaterialProperty({ color: Cesium.Color.fromCssColorString('#10B981') })
          }
        });
      }
      pts.forEach((step) => {
        addEnt(
          {
            position: Cesium.Cartesian3.fromDegrees(step.coords[1], step.coords[0], 20),
            billboard: {
              image: makeStepSvgUri(step.stepNumber),
              width: 26,
              height: 26,
              disableDepthTestDistance: Number.POSITIVE_INFINITY
            }
          },
          { kind: 'story', step }
        );
      });
    }

    // Real User Pins
    mappedUsers.forEach((user) => {
      const isSelected = selectedUser?.id === user.id;
      const isEmergency = Boolean(user.isFreshSos || user.isTestSos);
      const displayCoords =
        playbackProgress < 0.99
          ? interpolateUserTrack(user, playbackProgress) || user.coords
          : user.coords;
      const [uLat, uLng] = displayCoords;

      if (isEmergency || isSelected) {
        const ringColor = isEmergency ? Cesium.Color.RED : Cesium.Color.CYAN;
        addEnt({
          position: Cesium.Cartesian3.fromDegrees(uLng, uLat),
          ellipse: {
            semiMajorAxis: isEmergency ? 220 : 120,
            semiMinorAxis: isEmergency ? 220 : 120,
            material: ringColor.withAlpha(0.15),
            outline: true,
            outlineColor: ringColor
          }
        });
      }

      addEnt(
        {
          position: Cesium.Cartesian3.fromDegrees(uLng, uLat, 25),
          billboard: {
            image: makeUserSvgUri(user, isSelected),
            width: isSelected ? 42 : 36,
            height: isSelected ? 42 : 36,
            disableDepthTestDistance: Number.POSITIVE_INFINITY
          },
          label: {
            text: (user.name ? user.name.split(' ')[0] : 'Kullanıcı').toUpperCase(),
            font: '10px "Share Tech Mono", monospace',
            fillColor: isEmergency ? Cesium.Color.fromCssColorString('#FCA5A5') : Cesium.Color.WHITE,
            outlineColor: Cesium.Color.BLACK,
            outlineWidth: 3,
            style: Cesium.LabelStyle.FILL_AND_OUTLINE,
            pixelOffset: new Cesium.Cartesian2(0, 26),
            disableDepthTestDistance: Number.POSITIVE_INFINITY
          }
        },
        { kind: 'user', user }
      );
    });
  }, [
    mappedUsers, selectedUser, playbackProgress, showHazards, hazardZones,
    showSarGrid, sarGrid, showBreadcrumbs, breadcrumbTrail, focalUser,
    showSarVectors, analysis, lkpProbability, uavPosition, uavTargetUser, uavOrbitAngle,
    showSmartCone, enableSmartCone, smartSearchCone, showDispatchedTeams, enableTeams,
    dispatchedTeams, showStoryline, enableStoryline, incidentStoryline
  ]);

  return (
    <div className="relative w-full h-full bg-[#02040A] overflow-hidden select-none font-tactical">
      {/* 1. TACTICAL VIGNETTE & CORNER HUD RETICLES */}
      <div className="absolute inset-0 tactical-vignette z-20 pointer-events-none" />

      <div className="absolute top-2 left-2 z-20 pointer-events-none text-cyan-500/50 text-[10px] font-mono flex items-center gap-1">
        <span>+</span><span>CESIUM_3D [38.5N]</span>
      </div>
      <div className="absolute top-2 right-2 z-20 pointer-events-none text-cyan-500/50 text-[10px] font-mono flex items-center gap-1">
        <span>GLOBE_ENGINE [27.2E]</span><span>+</span>
      </div>
      <div className="absolute bottom-10 left-2 z-20 pointer-events-none text-cyan-500/40 text-[10px] font-mono">
        + SECTOR_WEST_GRID
      </div>
      <div className="absolute bottom-10 right-2 z-20 pointer-events-none text-cyan-500/40 text-[10px] font-mono">
        SECTOR_EAST_GRID +
      </div>

      {enableRadarEffect && (
        <div className="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-[700px] h-[700px] z-10 pointer-events-none overflow-hidden">
          <div className="radar-sweep-beam" />
          <div className="absolute inset-0 border border-cyan-500/10 rounded-full" />
          <div className="absolute inset-[15%] border border-cyan-500/10 rounded-full" />
          <div className="absolute inset-[30%] border border-cyan-500/10 rounded-full" />
        </div>
      )}

      {/* 2. TOP-CENTER FLOATING TACTICAL STATS & FEATURE TOGGLE BAR */}
      <div className="absolute top-3 left-1/2 transform -translate-x-1/2 z-[400] flex flex-col items-center gap-2 pointer-events-none">
        <div className="flex items-center gap-2 pointer-events-auto">
          <div className="tactical-box px-3 py-1 flex items-center gap-2">
            <div className="text-[9px] text-cyan-400 font-bold tracking-widest uppercase">TOPLAM KADRO</div>
            <span className="text-sm font-black text-white font-mono">{users.length}</span>
          </div>
          <div className="tactical-box px-3 py-1 flex items-center gap-2">
            <div className="text-[9px] text-emerald-400 font-bold tracking-widest uppercase flex items-center gap-1">
              <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
              GPS TELEMETRİ
            </div>
            <span className="text-sm font-black text-[#00E5FF] font-mono">{mappedUsers.length}</span>
          </div>
          <div className={`px-3 py-1 flex items-center gap-2 border ${
            activeSosUser
              ? 'bg-red-950/90 border-red-500 shadow-[0_0_12px_rgba(239,68,68,0.5)] animate-pulse'
              : 'tactical-box'
          }`}>
            <div className="text-[9px] font-bold tracking-widest uppercase flex items-center gap-1">
              {activeSosUser ? <span className="w-1.5 h-1.5 rounded-full bg-red-500 animate-ping" /> : null}
              <span className={activeSosUser ? 'text-red-200' : 'text-slate-400'}>CANLI ACİL SOS</span>
            </div>
            <span className={`text-sm font-black font-mono ${activeSosUser ? 'text-red-400' : 'text-slate-300'}`}>
              {activeSosUser ? '🚨 AKTİF' : '0'}
            </span>
          </div>
        </div>

        <div className="bg-[#02050D]/90 backdrop-blur-md border border-cyan-500/30 px-3 py-1 flex items-center gap-2 pointer-events-auto text-[10px] font-mono flex-wrap justify-center">
          <button
            onClick={() => { setShowBreadcrumbs(!showBreadcrumbs); soundFx.playSelect(); }}
            className={`px-2 py-0.5 border flex items-center gap-1 transition-colors cursor-pointer ${
              showBreadcrumbs ? 'border-[#FF4D26] bg-[#FF4D26]/20 text-[#FF6E40] font-bold' : 'border-slate-800 text-slate-500 hover:text-slate-300'
            }`}
          >
            <Route className="w-3 h-3" />
            <span>ROTA: {showBreadcrumbs ? 'AÇIK' : 'KAPALI'}</span>
          </button>
          <button
            onClick={() => { setShowSarVectors(!showSarVectors); soundFx.playSelect(); }}
            className={`px-2 py-0.5 border flex items-center gap-1 transition-colors cursor-pointer ${
              showSarVectors ? 'border-[#00E5FF] bg-[#00E5FF]/20 text-[#00E5FF] font-bold' : 'border-slate-800 text-slate-500 hover:text-slate-300'
            }`}
          >
            <Navigation2 className="w-3 h-3" />
            <span>İNTİKAL: {showSarVectors ? 'AÇIK' : 'KAPALI'}</span>
          </button>
          <button
            onClick={() => { setShowSarGrid(!showSarGrid); soundFx.playSelect(); }}
            className={`px-2 py-0.5 border flex items-center gap-1 transition-colors cursor-pointer ${
              showSarGrid ? 'border-emerald-500 bg-emerald-500/20 text-emerald-400 font-bold' : 'border-slate-800 text-slate-500 hover:text-slate-300'
            }`}
          >
            <Grid className="w-3 h-3" />
            <span>SAR IZGARA: {showSarGrid ? 'AÇIK' : 'KAPALI'}</span>
          </button>
          <button
            onClick={() => { setShowHazards(!showHazards); soundFx.playSelect(); }}
            className={`px-2 py-0.5 border flex items-center gap-1 transition-colors cursor-pointer ${
              showHazards ? 'border-red-500 bg-red-950/40 text-red-300 font-bold' : 'border-slate-800 text-slate-500 hover:text-slate-300'
            }`}
          >
            <ShieldAlert className="w-3 h-3 text-red-400" />
            <span>TEHLİKE BÖLGELERİ: {showHazards ? 'AÇIK' : 'KAPALI'}</span>
          </button>
        </div>
      </div>

      {/* 2. TOP TARGETING NOTIFICATION BANNER */}
      {directingTeam && (
        <div className="absolute top-12 left-1/2 transform -translate-x-1/2 z-[500] bg-[#02050D]/95 border-2 border-amber-400 p-2.5 px-4 shadow-[0_0_30px_rgba(245,158,11,0.6)] flex items-center gap-3 animate-pulse font-tactical">
          <Compass className="w-5 h-5 text-amber-400 animate-spin" />
          <div>
            <div className="text-xs font-black text-amber-300 font-mono tracking-wider">
              🎯 HAREKAT YÖNLENDİRME: {directingTeam.name}
            </div>
            <div className="text-[10px] text-white font-mono">
              3D Küre üzerinde sevk etmek istediğiniz hedef mevkiye tıklayın
            </div>
          </div>
          <div className="flex items-center gap-2 ml-2">
            {focalUser?.coords && (
              <button
                onClick={() => onDispatchToCasualty(directingTeam.id)}
                className="bg-red-700 hover:bg-red-600 text-white font-mono text-[10px] px-2.5 py-1 font-bold cursor-pointer"
              >
                KAZAZEDEYE GÖNDER
              </button>
            )}
            <button
              onClick={onCancelDirecting}
              className="bg-slate-800 hover:bg-slate-700 text-slate-300 font-mono text-[10px] px-2 py-1 cursor-pointer"
            >
              İPTAL
            </button>
          </div>
        </div>
      )}

      {/* 3. FLOATING QUICK RESCUE TEAM DISPATCH BAR */}
      <div className="absolute top-14 left-3 z-[400] bg-[#02050D]/90 backdrop-blur-md border border-cyan-500/40 p-2 text-xs font-mono select-none w-72 shadow-[0_0_20px_rgba(0,0,0,0.8)]">
        <div className="flex items-center justify-between border-b border-cyan-500/30 pb-1 mb-1.5">
          <span className="text-[10px] font-bold text-cyan-300 flex items-center gap-1.5">
            <Shield className="w-3.5 h-3.5 text-cyan-400" />
            SEVK EDİLEN EKİPLER ({dispatchedTeams.length})
          </span>
          <button
            onClick={onOpenAddTeam}
            className="text-[9px] bg-cyan-950 hover:bg-cyan-900 border border-cyan-400 text-cyan-200 px-1.5 py-0.2 font-bold cursor-pointer flex items-center gap-0.5"
          >
            <Plus className="w-2.5 h-2.5" /> EKİP EKLE
          </button>
        </div>

        <div className="space-y-1 max-h-36 overflow-y-auto custom-scrollbar pr-1">
          {dispatchedTeams.length === 0 ? (
            <div className="text-[10px] text-slate-500 text-center py-2">
              Henüz sevk edilmiş ekip yok. (+ EKİP EKLE)
            </div>
          ) : (
            dispatchedTeams.map((t) => {
              const hasTarget = Boolean(t.targetCoords);
              const isDirectingThis = directingTeamId === t.id;
              return (
                <div
                  key={t.id}
                  className={`p-1.5 border flex items-center justify-between text-[10px] transition-colors ${
                    isDirectingThis
                      ? 'border-amber-400 bg-amber-950/60 shadow-[0_0_10px_rgba(245,158,11,0.3)]'
                      : 'border-slate-800 bg-[#040816] hover:border-slate-700'
                  }`}
                >
                  <div
                    onClick={() => onCenterTarget(t.coords, 16)}
                    className="flex items-center gap-1.5 cursor-pointer truncate mr-2 flex-1"
                  >
                    <span className="w-2 h-2 rounded-full shrink-0" style={{ backgroundColor: t.color || '#00E5FF' }} />
                    <span className="font-bold text-white truncate">{t.shortName}</span>
                    <span className="text-[8.5px] text-slate-400">({t.personnel}p)</span>
                  </div>
                  <div className="flex items-center gap-1 shrink-0">
                    {hasTarget && (
                      <span className="text-[8.5px] text-amber-300 font-bold bg-amber-950 px-1 border border-amber-600/50 animate-pulse">
                        İNTİKALDE
                      </span>
                    )}
                    <button
                      onClick={() => {
                        if (isDirectingThis) onCancelDirecting();
                        else { onStartDirecting(t.id); soundFx.playTargetLock(); }
                      }}
                      className={`px-1.5 py-0.5 text-[8.5px] font-bold cursor-pointer border ${
                        isDirectingThis
                          ? 'bg-amber-400 text-black border-amber-300 font-black'
                          : 'bg-cyan-950 text-cyan-200 border-cyan-500/40 hover:bg-cyan-900'
                      }`}
                    >
                      {isDirectingThis ? 'HEDEF SEÇ' : 'YÖNLENDİR'}
                    </button>
                    <button
                      onClick={() => {
                        if (window.confirm(`${t.name} görevden çekilsin mi?`)) {
                          onRemoveTeam(t.id);
                          soundFx.playSelect();
                        }
                      }}
                      className="p-0.5 text-slate-500 hover:text-red-400 cursor-pointer"
                    >
                      <X className="w-3 h-3" />
                    </button>
                  </div>
                </div>
              );
            })
          )}
        </div>
      </div>

      {/* 3D PICKED ENTITY POPUP CARD */}
      {popupItem && (
        <div className="absolute bottom-14 right-4 z-[500] w-72 bg-[#02050D]/95 border border-cyan-500/60 p-3 text-slate-100 shadow-[0_0_25px_rgba(0,0,0,0.95)] font-mono">
          <button
            onClick={() => setPopupItem(null)}
            className="absolute top-2 right-2 text-slate-400 hover:text-white cursor-pointer"
          >
            <X className="w-3.5 h-3.5" />
          </button>

          {popupItem.kind === 'user' && popupItem.user && (
            <div>
              <div className="font-bold text-xs text-white uppercase">{popupItem.user.name}</div>
              <div className="text-[10px] text-[#FF6E40] mb-1">{popupItem.user.team}</div>
              <div className="text-[9.5px] text-cyan-400 mb-2">
                {popupItem.user.lat.toFixed(4)}°N, {popupItem.user.lng.toFixed(4)}°E
              </div>
              <div className="grid grid-cols-2 gap-1 text-[10px] bg-[#030917] p-1.5 border border-slate-800 mb-2">
                <div>RAKIM: <span className="text-amber-300 font-bold">{popupItem.user.altitude}m</span></div>
                <div>BATARYA: <span className="text-emerald-400 font-bold">%{popupItem.user.battery}</span></div>
              </div>
              <button
                onClick={() => { handleDirectSelect(popupItem.user); setPopupItem(null); }}
                className="w-full tactical-btn py-1.5 text-[10px] flex items-center justify-center gap-1 cursor-pointer"
              >
                <Eye className="w-3.5 h-3.5 text-[#00E5FF]" /> DETAYLI KOKPİTE AL
              </button>
            </div>
          )}

          {popupItem.kind === 'team' && popupItem.team && (
            <div className="space-y-1.5 text-[10px]">
              <div className="font-bold text-cyan-300 uppercase">{popupItem.team.name}</div>
              <div className="text-slate-300">LİDER: <span className="text-white font-bold">{popupItem.team.leader}</span> ({popupItem.team.personnel}p)</div>
              <div className="text-slate-300">TELSİZ: <span className="text-cyan-400">{popupItem.team.radioChannel}</span></div>
              <div className="grid grid-cols-2 gap-1 pt-1">
                <button
                  onClick={() => { onStartDirecting(popupItem.team.id); soundFx.playTargetLock(); setPopupItem(null); }}
                  className="bg-cyan-950 hover:bg-cyan-900 border border-cyan-400 text-cyan-200 py-1 font-bold cursor-pointer"
                >
                  HEDEF BELİRLE
                </button>
                <button
                  onClick={() => { onDispatchToCasualty(popupItem.team.id); soundFx.playTargetLock(); setPopupItem(null); }}
                  className="bg-red-950 hover:bg-red-900 border border-red-500 text-red-300 py-1 font-bold cursor-pointer flex items-center justify-center gap-1"
                >
                  <Zap className="w-3 h-3" /> KAZAZEDEYE
                </button>
              </div>
              {popupItem.team.targetCoords && (
                <button
                  onClick={() => { onCompleteTransit(popupItem.team.id); soundFx.playSuccess(); setPopupItem(null); }}
                  className="w-full bg-emerald-950 hover:bg-emerald-900 border border-emerald-500 text-emerald-300 py-1 font-bold cursor-pointer"
                >
                  ✅ VARIŞI ONAYLA
                </button>
              )}
              <button
                onClick={() => {
                  if (window.confirm(`${popupItem.team.name} görevden çekilsin mi?`)) {
                    onRemoveTeam(popupItem.team.id);
                    setPopupItem(null);
                  }
                }}
                className="w-full bg-black hover:bg-red-950 border border-slate-800 text-slate-400 hover:text-red-300 py-1 cursor-pointer flex items-center justify-center gap-1"
              >
                <Trash2 className="w-3 h-3" /> EKİBİ SİL
              </button>
            </div>
          )}

          {popupItem.kind === 'teamTarget' && popupItem.team && (
            <div className="space-y-1.5 text-[10px]">
              <div className="font-bold text-amber-300">🎯 {popupItem.team.name} İNTİKAL HEDEFİ</div>
              <div className="text-slate-300">
                MESAFE: {calculateDistanceMeters(popupItem.team.coords[0], popupItem.team.coords[1], popupItem.team.targetCoords[0], popupItem.team.targetCoords[1])}m • ~{calculateEtaMinutes(calculateDistanceMeters(popupItem.team.coords[0], popupItem.team.coords[1], popupItem.team.targetCoords[0], popupItem.team.targetCoords[1]), 4.5)} dk
              </div>
              <button
                onClick={() => { onCompleteTransit(popupItem.team.id); setPopupItem(null); }}
                className="w-full bg-emerald-700 hover:bg-emerald-600 text-white font-bold py-1 cursor-pointer"
              >
                ✅ VARIŞI ONAYLA
              </button>
            </div>
          )}

          {popupItem.kind === 'story' && popupItem.step && (
            <div className="space-y-1 text-[10px]">
              <div className="font-bold text-emerald-400">ADIM {popupItem.step.stepNumber}: [{popupItem.step.time}] {popupItem.step.title}</div>
              <p className="text-slate-300 leading-relaxed">{popupItem.step.desc}</p>
              <div className="text-slate-400">SORUMLU: <span className="text-cyan-300 font-bold">{popupItem.step.team}</span></div>
            </div>
          )}
        </div>
      )}

      {/* 4. CESIUMJS 3D GLOBE VIEWPORT */}
      <div ref={containerRef} className="w-full h-full z-10" />

      {/* 5. BOTTOM-CENTER CURSOR COORDINATES & RADAR TOGGLE */}
      <div className="absolute bottom-2 left-1/2 transform -translate-x-1/2 z-[400] pointer-events-none select-none">
        <div className="bg-[#02050D]/90 backdrop-blur-md border border-cyan-500/30 px-4 py-1 flex items-center gap-4 text-[10px] font-mono text-slate-300 pointer-events-auto">
          <div className="flex items-center gap-1 text-cyan-400">
            <Crosshair className="w-3 h-3 text-[#00E5FF]" />
            <span className="text-slate-400">KURSÖR:</span>
            <span className="font-bold text-white">{mouseCoords[0].toFixed(4)}°N, {mouseCoords[1].toFixed(4)}°E</span>
          </div>
          <div className="w-[1px] h-3 bg-slate-800" />
          <div className="text-amber-400 font-bold">
            SEKTÖR: {analysis?.sectorName ? analysis.sectorName.split('/')[0] : 'İZMİR'}
          </div>
          <div className="w-[1px] h-3 bg-slate-800" />
          <button
            onClick={() => setEnableSmartCone(!enableSmartCone)}
            className={`cursor-pointer transition-colors ${enableSmartCone ? 'text-amber-300 font-bold' : 'text-slate-600'}`}
          >
            🎯 KONİ: {enableSmartCone ? 'AÇIK' : 'KAPALI'}
          </button>
          <div className="w-[1px] h-3 bg-slate-800" />
          <button
            onClick={() => setEnableTeams(!enableTeams)}
            className={`cursor-pointer transition-colors ${enableTeams ? 'text-cyan-400 font-bold' : 'text-slate-600'}`}
          >
            🛡️ EKİP ({dispatchedTeams.length}): {enableTeams ? 'AÇIK' : 'KAPALI'}
          </button>
          <div className="w-[1px] h-3 bg-slate-800" />
          <button
            onClick={() => setEnableStoryline(!enableStoryline)}
            className={`cursor-pointer transition-colors ${enableStoryline ? 'text-emerald-400 font-bold' : 'text-slate-600'}`}
          >
            📋 OLAY ÖRGÜSÜ: {enableStoryline ? 'AÇIK' : 'KAPALI'}
          </button>
          <div className="w-[1px] h-3 bg-slate-800" />
          <button
            onClick={() => setEnableRadarEffect(!enableRadarEffect)}
            className={`flex items-center gap-1 cursor-pointer transition-colors ${enableRadarEffect ? 'text-[#00E5FF] font-bold' : 'text-slate-500'}`}
          >
            <Radar className={`w-3 h-3 ${enableRadarEffect ? 'animate-spin' : ''}`} />
            <span>RADAR: {enableRadarEffect ? 'AÇIK' : 'KAPALI'}</span>
          </button>
        </div>
      </div>
    </div>
  );
}
