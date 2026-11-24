export function downloadCsv(filename, headers, rows) {
  const escapeCell = (val) => {
    const str = val == null ? '' : String(val);
    return `"${str.replace(/"/g, '""')}"`;
  };
  const lines = [
    headers.map(escapeCell).join(';'),
    ...rows.map((r) => r.map(escapeCell).join(';')),
  ];
  const bom = '\uFEFF';
  const blob = new Blob([bom + lines.join('\r\n')], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

export function haversineKm(lat1, lng1, lat2, lng2) {
  const toRad = (d) => (d * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function printIncidentReport(rep) {
  const w = window.open('', '_blank', 'width=820,height=900');
  if (!w) return;
  const esc = (s) =>
    String(s ?? '-')
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;');
  const coords =
    rep.lat != null && rep.lng != null
      ? `${Number(rep.lat).toFixed(5)}, ${Number(rep.lng).toFixed(5)}`
      : 'Yok';
  const imgTag = rep.imageBase64
    ? `<div style="margin-top:16px;"><img src="data:image/jpeg;base64,${rep.imageBase64}" style="max-width:100%;max-height:320px;border:1px solid #ccc;" /></div>`
    : '';
  w.document.write(`<!doctype html>
  <html lang="tr"><head><meta charset="utf-8"><title>ROTA+ Olay Raporu</title>
  <style>
    body{font-family:Arial,sans-serif;padding:28px;color:#111;line-height:1.5;}
    h1{font-size:18px;border-bottom:2px solid #111;padding-bottom:8px;margin-bottom:16px;}
    table{width:100%;border-collapse:collapse;margin-bottom:16px;font-size:13px;}
    td,th{border:1px solid #ccc;padding:8px;text-align:left;}
    th{background:#f3f4f6;width:180px;}
    .box{border:1px solid #ccc;padding:12px;background:#fafafa;font-size:13px;}
  </style></head><body>
  <h1>ROTA+ RESMİ AFET &amp; OLAY İHBAR RAPORU</h1>
  <table>
    <tr><th>Olay Türü</th><td>${esc(rep.disasterType)}</td></tr>
    <tr><th>Durum</th><td>${esc(rep.status || 'YENİ')}</td></tr>
    <tr><th>Tarih / Saat</th><td>${esc(rep.dateTimeStr)}</td></tr>
    <tr><th>İhbarcı Adı</th><td>${esc(rep.reporterName)}</td></tr>
    <tr><th>Telefon</th><td>${esc(rep.reporterPhone)}</td></tr>
    <tr><th>IP Adresi</th><td>${esc(rep.reporterIp || 'Alınamadı')}</td></tr>
    <tr><th>İl / İlçe</th><td>${esc(rep.province || '-')} / ${esc(rep.district || '-')}</td></tr>
    <tr><th>Mahalle / Sokak</th><td>${esc(rep.neighborhood || '-')} / ${esc(rep.street || '-')}</td></tr>
    <tr><th>GPS Koordinatı</th><td>${esc(coords)}</td></tr>
  </table>
  <div class="box"><strong>Olay Özeti:</strong><br/>${esc(rep.summary)}</div>
  ${imgTag}
  <script>window.onload=function(){window.print();}</script>
  </body></html>`);
  w.document.close();
}
