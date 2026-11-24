import React, { useMemo } from 'react';

export default function StatsAndAnalyticsTab({
  users = [],
  posts = [],
  incidents = [],
  fires = [],
  safeZones = [],
  hazardZones = [],
  bannedIpsCount = 0,
}) {
  const analytics = useMemo(() => {
    const byType = {};
    const byProvince = {};
    const byStatus = { 'YENİ': 0, 'İNCELENİYOR': 0, 'SEVK EDİLDİ': 0, 'ÇÖZÜLDÜ': 0 };

    incidents.forEach((r) => {
      const t = r.disasterType || 'Diğer';
      byType[t] = (byType[t] || 0) + 1;

      const prov = (r.province || '').trim() || 'Belirtilmedi';
      byProvince[prov] = (byProvince[prov] || 0) + 1;

      const st = r.status || 'YENİ';
      byStatus[st] = (byStatus[st] || 0) + 1;
    });

    const typeRows = Object.entries(byType).sort((a, b) => b[1] - a[1]);
    const provRows = Object.entries(byProvince).sort((a, b) => b[1] - a[1]).slice(0, 8);
    const maxType = typeRows[0]?.[1] || 1;
    const maxProv = provRows[0]?.[1] || 1;

    return { typeRows, provRows, byStatus, maxType, maxProv };
  }, [incidents]);

  const premiumCount = users.filter((u) => u.is_premium === true).length;

  return (
    <div className="space-y-4">
      <div className="grid gap-3 sm:grid-cols-4">
        <MetricBox title="TOPLAM OPERATÖR" value={users.length} sub={`${premiumCount} Premium`} color="text-[#00E5FF]" />
        <MetricBox title="TOPLAM İHBAR" value={incidents.length} sub={`${analytics.byStatus['ÇÖZÜLDÜ']} Çözüldü`} color="text-amber-400" />
        <MetricBox title="TOPLAM GÖNDERİ" value={posts.length} sub={`${fires.length} Yangın Kaydı`} color="text-emerald-400" />
        <MetricBox title="SAHA BÖLGELERİ" value={safeZones.length + hazardZones.length} sub={`${safeZones.length} Güvenli • ${hazardZones.length} Riskli • ${bannedIpsCount} Engelli IP`} color="text-[#FF4D26]" />
      </div>

      <div className="grid gap-4 md:grid-cols-2">
        <div className="bg-[#040814] border border-[#00E5FF]/30 p-4 space-y-3">
          <div className="text-xs font-bold text-[#00E5FF] uppercase">AFET / OLAY TÜRÜ DAĞILIMI</div>
          {analytics.typeRows.length === 0 ? (
            <div className="text-xs text-slate-500">Veri yok.</div>
          ) : (
            analytics.typeRows.map(([label, count]) => (
              <BarRow key={label} label={label} count={count} max={analytics.maxType} barClass="bg-[#FF4D26]" />
            ))
          )}
        </div>

        <div className="bg-[#040814] border border-[#00E5FF]/30 p-4 space-y-3">
          <div className="text-xs font-bold text-[#00E5FF] uppercase">İL BAZLI İHBAR YOĞUNLUĞU</div>
          {analytics.provRows.length === 0 ? (
            <div className="text-xs text-slate-500">Veri yok.</div>
          ) : (
            analytics.provRows.map(([label, count]) => (
              <BarRow key={label} label={label} count={count} max={analytics.maxProv} barClass="bg-[#00E5FF]" />
            ))
          )}
        </div>
      </div>

      <div className="bg-[#040814] border border-slate-800 p-4">
        <div className="text-xs font-bold text-amber-300 uppercase mb-3">İHBAR ÇÖZÜM SÜRECİ DAĞILIMI</div>
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
          {Object.entries(analytics.byStatus).map(([st, cnt]) => (
            <div key={st} className="bg-[#02050D] border border-slate-800 p-3">
              <div className="text-[10px] text-slate-400">{st}</div>
              <div className="text-2xl font-black text-white mt-1">{cnt}</div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

function MetricBox({ title, value, sub, color }) {
  return (
    <div className="bg-[#040814] border border-slate-800 p-4">
      <div className="text-[10px] text-slate-400">{title}</div>
      <div className={`text-2xl font-black mt-1 ${color}`}>{value}</div>
      <div className="text-[11px] text-slate-400 mt-1">{sub}</div>
    </div>
  );
}

function BarRow({ label, count, max, barClass }) {
  const pct = Math.max(6, Math.round((count / max) * 100));
  return (
    <div className="space-y-1 text-xs">
      <div className="flex justify-between">
        <span className="text-slate-200">{label}</span>
        <span className="text-white font-bold">{count}</span>
      </div>
      <div className="h-2 bg-[#02050D] border border-slate-800">
        <div className={`h-full ${barClass}`} style={{ width: `${pct}%` }} />
      </div>
    </div>
  );
}
