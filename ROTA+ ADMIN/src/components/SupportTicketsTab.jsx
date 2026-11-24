import React, { useState } from 'react';
import { LifeBuoy, Send, Trash2, CheckCircle2 } from 'lucide-react';
import { replySupportTicket, updateDocByPath, deleteDocByPath } from '../firebase';

export default function SupportTicketsTab({ tickets = [] }) {
  const [replyMap, setReplyMap] = useState({});

  if (tickets.length === 0) {
    return (
      <div className="py-12 text-center text-xs text-slate-500">
        HENÜZ KULLANICI DESTEK / HATA TALEBİ YOK.
      </div>
    );
  }

  return (
    <div className="space-y-3">
      {tickets.map((t) => {
        const draft = replyMap[t.id] ?? '';
        return (
          <div key={t.id} className="bg-[#040814] border border-slate-800 p-4 space-y-2.5">
            <div className="flex flex-wrap items-center justify-between gap-2 border-b border-slate-800 pb-2">
              <div className="flex items-center gap-2">
                <LifeBuoy className="w-4 h-4 text-[#00E5FF]" />
                <span className="text-xs font-bold text-white">{t.userName || t.userEmail || 'Operatör'}</span>
                <span className="px-2 py-0.5 bg-amber-950/60 border border-amber-500/40 text-amber-300 text-[10px]">
                  {t.category || 'GENEL'}
                </span>
                <span className="px-2 py-0.5 bg-cyan-950/60 border border-[#00E5FF]/40 text-[#00E5FF] text-[10px]">
                  {t.status || 'AÇIK'}
                </span>
              </div>
              <div className="flex items-center gap-2">
                <button
                  onClick={() => updateDocByPath('support_tickets', t.id, { status: 'ÇÖZÜLDÜ' })}
                  className="px-2 py-1 border border-emerald-500/50 text-emerald-300 text-[10px] flex items-center gap-1 cursor-pointer"
                >
                  <CheckCircle2 className="w-3 h-3" /> ÇÖZÜLDÜ
                </button>
                <button
                  onClick={() => deleteDocByPath('support_tickets', t.id)}
                  className="text-red-400 hover:text-red-300 p-1 cursor-pointer"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>

            <div className="text-xs font-bold text-amber-200">{t.subject || 'Destek Talebi'}</div>
            <p className="text-xs text-slate-300 bg-[#02050D] border border-slate-800 p-2.5">{t.message || ''}</p>

            {t.adminReply && (
              <div className="text-xs text-emerald-200 bg-emerald-950/30 border border-emerald-500/30 p-2.5">
                <strong>Admin Yanıtı:</strong> {t.adminReply}
              </div>
            )}

            <div className="flex gap-2">
              <input
                value={draft}
                onChange={(e) => setReplyMap((p) => ({ ...p, [t.id]: e.target.value }))}
                placeholder="Kullanıcıya yanıt yazın (bildirim olarak gider)..."
                className="flex-1 bg-[#02050D] border border-slate-700 px-3 py-1.5 text-xs text-white focus:border-[#00E5FF] focus:outline-none"
              />
              <button
                onClick={async () => {
                  if (!draft.trim()) return;
                  await replySupportTicket({ ticket: t, replyText: draft });
                  setReplyMap((p) => ({ ...p, [t.id]: '' }));
                }}
                className="px-3 py-1.5 bg-[#00E5FF] text-black font-bold text-xs flex items-center gap-1 cursor-pointer"
              >
                <Send className="w-3.5 h-3.5" /> YANITLA
              </button>
            </div>
          </div>
        );
      })}
    </div>
  );
}
