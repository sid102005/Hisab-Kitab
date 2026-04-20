import React, { useEffect, useState, useRef } from 'react';

const WS_URL = 'ws://192.168.22.222:8000/ws/alerts';

export default function AlertPanel() {
  const [alerts, setAlerts] = useState([]);
  const [connected, setConnected] = useState(false);
  const [expanded, setExpanded] = useState(false);
  const wsRef = useRef(null);
  const pingRef = useRef(null);

  useEffect(() => {
    let ws;
    const connect = () => {
      ws = new WebSocket(WS_URL);
      wsRef.current = ws;

      ws.onopen = () => {
        setConnected(true);
        pingRef.current = setInterval(() => {
          if (ws.readyState === WebSocket.OPEN) ws.send('ping');
        }, 20000);
      };

      ws.onmessage = (e) => {
        try {
          const data = JSON.parse(e.data);
          if (data.type === 'pong') return;
          setAlerts(prev => [data, ...prev].slice(0, 50));
        } catch {}
      };

      ws.onclose = () => {
        setConnected(false);
        clearInterval(pingRef.current);
        setTimeout(connect, 5000); // reconnect
      };

      ws.onerror = () => ws.close();
    };

    connect();
    return () => {
      clearInterval(pingRef.current);
      if (wsRef.current) wsRef.current.close();
    };
  }, []);

  const unread = alerts.filter(a => !a.read).length;

  const severityColor = { high: '#ef4444', medium: '#f59e0b', low: '#3b82f6' };

  return (
    <div style={s.wrapper}>
      {/* Toggle button */}
      <button onClick={() => setExpanded(!expanded)} style={s.toggleBtn}>
        🔔 {unread > 0 && <span style={s.badge}>{unread}</span>}
        <span style={{ width: 8, height: 8, borderRadius: '50%', background: connected ? '#10b981' : '#ef4444', display: 'inline-block', marginLeft: 6 }} />
      </button>

      {/* Panel */}
      {expanded && (
        <div style={s.panel}>
          <div style={s.panelHeader}>
            <span style={{ fontWeight: 600, color: '#f1f5f9' }}>🔔 Live Alerts</span>
            <span style={{ fontSize: 11, color: connected ? '#10b981' : '#ef4444' }}>
              {connected ? '● Connected' : '● Disconnected'}
            </span>
          </div>
          <div style={s.alertList}>
            {alerts.length === 0 ? (
              <div style={s.empty}>No alerts yet. Monitoring...</div>
            ) : (
              alerts.map((a, i) => (
                <div key={i} style={{ ...s.alert, borderLeftColor: severityColor[a.severity] || '#3b82f6' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'start' }}>
                    <div style={{ fontWeight: 600, fontSize: 13, color: '#f1f5f9' }}>{a.title}</div>
                    <span style={{ ...s.sevBadge, background: severityColor[a.severity] || '#3b82f6' }}>
                      {a.severity}
                    </span>
                  </div>
                  <div style={{ fontSize: 12, color: '#94a3b8', marginTop: 4 }}>{a.message}</div>
                  <div style={{ fontSize: 10, color: '#64748b', marginTop: 4 }}>
                    {a.timestamp ? new Date(a.timestamp).toLocaleTimeString() : ''}
                  </div>
                </div>
              ))
            )}
          </div>
        </div>
      )}
    </div>
  );
}

const s = {
  wrapper: { position: 'fixed', top: 16, right: 16, zIndex: 1000 },
  toggleBtn: {
    padding: '10px 16px', borderRadius: 12, border: '1px solid #334155',
    background: '#1e293b', color: '#f1f5f9', cursor: 'pointer', fontSize: 18,
    display: 'flex', alignItems: 'center', gap: 4, boxShadow: '0 4px 12px rgba(0,0,0,0.3)',
  },
  badge: {
    background: '#ef4444', color: '#fff', borderRadius: '50%',
    width: 20, height: 20, display: 'inline-flex', alignItems: 'center',
    justifyContent: 'center', fontSize: 11, fontWeight: 700,
  },
  panel: {
    position: 'absolute', top: 50, right: 0, width: 380,
    background: '#1e293b', border: '1px solid #334155', borderRadius: 12,
    boxShadow: '0 8px 32px rgba(0,0,0,0.4)', overflow: 'hidden',
  },
  panelHeader: {
    display: 'flex', justifyContent: 'space-between', alignItems: 'center',
    padding: '12px 16px', borderBottom: '1px solid #334155',
  },
  alertList: { maxHeight: 400, overflowY: 'auto', padding: 8 },
  empty: { textAlign: 'center', color: '#64748b', padding: 32, fontSize: 13 },
  alert: {
    padding: 12, borderRadius: 8, marginBottom: 6,
    background: '#0f172a', borderLeft: '3px solid #3b82f6',
  },
  sevBadge: {
    fontSize: 10, padding: '2px 8px', borderRadius: 4, color: '#fff',
    fontWeight: 600, textTransform: 'uppercase', flexShrink: 0,
  },
};
