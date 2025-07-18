import React from 'react';
import './Dashboard.css';

interface DashboardProps {
  onLogout: () => void;
}

const Dashboard: React.FC<DashboardProps> = ({ onLogout }) => {
  return (
    <div className="dashboard-container">
      <header className="dashboard-header">
        <div className="header-content">
          <div className="logo">
            <div className="logo-icon">
              <svg viewBox="0 0 24 24" fill="currentColor">
                <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 3c1.93 0 3.5 1.57 3.5 3.5S13.93 13 12 13s-3.5-1.57-3.5-3.5S10.07 6 12 6zm7 13H5v-.23c0-.62.28-1.2.76-1.58C7.47 15.82 9.64 15 12 15s4.53.82 6.24 2.19c.48.38.76.97.76 1.58V19z"/>
              </svg>
            </div>
            <h1>ProjectFlow</h1>
          </div>
          <div className="user-menu">
            <span>Welcome back, User!</span>
            <button className="logout-btn" onClick={onLogout}>Logout</button>
          </div>
        </div>
      </header>

      <main className="dashboard-main">
        <div className="dashboard-content">
          <div className="welcome-section">
            <h2>Welcome to your Project Management Dashboard</h2>
            <p>Manage your projects, track progress, and collaborate with your team.</p>
          </div>

          <div className="stats-grid">
            <div className="stat-card">
              <div className="stat-icon">
                <svg viewBox="0 0 24 24" fill="currentColor">
                  <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-7 3c1.93 0 3.5 1.57 3.5 3.5S13.93 13 12 13s-3.5-1.57-3.5-3.5S10.07 6 12 6zm7 13H5v-.23c0-.62.28-1.2.76-1.58C7.47 15.82 9.64 15 12 15s4.53.82 6.24 2.19c.48.38.76.97.76 1.58V19z"/>
                </svg>
              </div>
              <div className="stat-info">
                <h3>Active Projects</h3>
                <p className="stat-number">12</p>
              </div>
            </div>

            <div className="stat-card">
              <div className="stat-icon">
                <svg viewBox="0 0 24 24" fill="currentColor">
                  <path d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"/>
                </svg>
              </div>
              <div className="stat-info">
                <h3>Completed Tasks</h3>
                <p className="stat-number">48</p>
              </div>
            </div>

            <div className="stat-card">
              <div className="stat-icon">
                <svg viewBox="0 0 24 24" fill="currentColor">
                  <path d="M12 2L2 7v10c0 5.55 3.84 9.74 9 11 5.16-1.26 9-5.45 9-11V7l-10-5z"/>
                </svg>
              </div>
              <div className="stat-info">
                <h3>Team Members</h3>
                <p className="stat-number">8</p>
              </div>
            </div>

            <div className="stat-card">
              <div className="stat-icon">
                <svg viewBox="0 0 24 24" fill="currentColor">
                  <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z"/>
                </svg>
              </div>
              <div className="stat-info">
                <h3>Pending Reviews</h3>
                <p className="stat-number">5</p>
              </div>
            </div>
          </div>

          <div className="recent-projects">
            <h3>Recent Projects</h3>
            <div className="projects-list">
              <div className="project-item">
                <div className="project-info">
                  <h4>Website Redesign</h4>
                  <p>UI/UX improvements for company website</p>
                </div>
                <div className="project-status">
                  <span className="status-badge in-progress">In Progress</span>
                </div>
              </div>

              <div className="project-item">
                <div className="project-info">
                  <h4>Mobile App Development</h4>
                  <p>React Native mobile application</p>
                </div>
                <div className="project-status">
                  <span className="status-badge planning">Planning</span>
                </div>
              </div>

              <div className="project-item">
                <div className="project-info">
                  <h4>Database Migration</h4>
                  <p>Upgrading to PostgreSQL 14</p>
                </div>
                <div className="project-status">
                  <span className="status-badge completed">Completed</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>
    </div>
  );
};

export default Dashboard;