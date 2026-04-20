import React, { useState } from 'react';
import { login, getMe } from '../api';

export default function LoginPage({ onLogin }) {
  const [username, setUsername] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError('');
    try {
      const data = await login(username, password);
      localStorage.setItem('token', data.access_token);
      const user = await getMe();
      localStorage.setItem('user', JSON.stringify(user));
      onLogin(user);
    } catch (err) {
      setError(err.response?.data?.detail || 'Login failed. Check server connection.');
    } finally {
      setLoading(false);
    }
  };

  const fillDemo = (u) => { setUsername(u); setPassword('admin123'); };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.header}>
          <span style={{ fontSize: 48 }}>🏛️</span>
          <h1 style={styles.title}>Hisab Kitab</h1>
          <p style={styles.subtitle}>Admin Dashboard</p>
        </div>

        <form onSubmit={handleSubmit} style={styles.form}>
          <input
            style={styles.input}
            placeholder="Username"
            value={username}
            onChange={e => setUsername(e.target.value)}
            required
          />
          <input
            style={styles.input}
            type="password"
            placeholder="Password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            required
          />
          <button style={styles.button} type="submit" disabled={loading}>
            {loading ? 'Signing in...' : 'Sign In'}
          </button>
          {error && <div style={styles.error}>{error}</div>}
        </form>

        <div style={styles.demoBox}>
          <p style={{ margin: '0 0 8px', fontWeight: 600, color: '#93c5fd' }}>Demo Accounts (password: admin123)</p>
          {[
            ['admin', 'Full access', '🔴'],
            ['health_dept', 'Health only', '🏥'],
            ['education_dept', 'Education only', '🎓'],
            ['public_user', 'Read-only', '👤'],
          ].map(([u, desc, icon]) => (
            <div key={u} onClick={() => fillDemo(u)} style={styles.demoItem}>
              <span>{icon} <strong>{u}</strong> — {desc}</span>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

const styles = {
  container: {
    minHeight: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center',
    background: 'linear-gradient(135deg, #0f172a 0%, #1e293b 100%)',
  },
  card: {
    background: '#1e293b', borderRadius: 16, padding: 40, width: 400,
    boxShadow: '0 25px 50px rgba(0,0,0,0.5)', border: '1px solid #334155',
  },
  header: { textAlign: 'center', marginBottom: 32 },
  title: { margin: '8px 0 0', color: '#f1f5f9', fontSize: 28 },
  subtitle: { margin: 0, color: '#94a3b8', fontSize: 14 },
  form: { display: 'flex', flexDirection: 'column', gap: 12 },
  input: {
    padding: '12px 16px', borderRadius: 8, border: '1px solid #475569',
    background: '#0f172a', color: '#f1f5f9', fontSize: 14, outline: 'none',
  },
  button: {
    padding: '12px', borderRadius: 8, border: 'none', background: '#2563eb',
    color: 'white', fontSize: 16, fontWeight: 600, cursor: 'pointer', marginTop: 4,
  },
  error: {
    background: '#7f1d1d', color: '#fca5a5', padding: '8px 12px', borderRadius: 8, fontSize: 13,
  },
  demoBox: {
    marginTop: 24, padding: 16, borderRadius: 12, background: '#0f172a', border: '1px solid #1e3a5f',
  },
  demoItem: {
    padding: '4px 0', cursor: 'pointer', color: '#cbd5e1', fontSize: 13,
  },
};
