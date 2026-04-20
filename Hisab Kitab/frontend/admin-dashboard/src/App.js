import React, { useState, useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, NavLink, Navigate, useNavigate } from 'react-router-dom';
import './App.css';
import LoginPage from './pages/LoginPage';
import OverviewPage from './pages/OverviewPage';
import IntelligencePage from './pages/IntelligencePage';
import AlertPanel from './components/AlertPanel';

function Sidebar({ user, onLogout }) {
  const navigate = useNavigate();
  const handleLogout = () => { onLogout(); navigate('/'); };

  return (
    <div className="sidebar">
      <div className="sidebar-brand">
        <span style={{ fontSize: 28 }}>📊</span>
        <div>
          <div style={{ fontWeight: 700, fontSize: 18, color: '#f1f5f9' }}>Hisab Kitab</div>
          <div style={{ fontSize: 11, color: '#64748b' }}>Admin Dashboard</div>
        </div>
      </div>

      <nav className="sidebar-nav">
        <NavLink to="/overview" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
          📊 Overview
        </NavLink>
        <NavLink to="/intelligence" className={({ isActive }) => `nav-item ${isActive ? 'active' : ''}`}>
          🧠 Intelligence
        </NavLink>
      </nav>

      <div className="sidebar-footer">
        <div style={{ fontSize: 13, color: '#94a3b8' }}>
          {user?.full_name || user?.username}
        </div>
        <div style={{ fontSize: 11, color: '#64748b', textTransform: 'uppercase' }}>
          {user?.role}
        </div>
        <button onClick={handleLogout} className="logout-btn">Logout</button>
      </div>
    </div>
  );
}

function App() {
  const [user, setUser] = useState(null);

  useEffect(() => {
    const saved = localStorage.getItem('user');
    if (saved) setUser(JSON.parse(saved));
  }, []);

  const handleLogin = (u) => setUser(u);

  const handleLogout = () => {
    localStorage.removeItem('token');
    localStorage.removeItem('user');
    setUser(null);
  };

  if (!user) return <LoginPage onLogin={handleLogin} />;

  return (
    <Router>
      <div className="app-layout">
        <Sidebar user={user} onLogout={handleLogout} />
        <main className="main-content">
          <AlertPanel />
          <Routes>
            <Route path="/overview" element={<OverviewPage />} />
            <Route path="/intelligence" element={<IntelligencePage user={user} />} />
            <Route path="*" element={<Navigate to="/overview" replace />} />
          </Routes>
        </main>
      </div>
    </Router>
  );
}

export default App;
