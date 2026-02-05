import { NavLink } from 'react-router-dom'
import styles from './Sidebar.module.css'

const navItems = [
  {
    to: '/dashboard',
    label: 'Dashboard',
    icon: <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z" />,
  },
  {
    to: '/users',
    label: 'Users',
    icon: <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5z" />,
    badgeKey: 'pendingUsers',
  },
  {
    to: '/readings',
    label: 'Readings',
    icon: <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />,
  },
  {
    to: '/charts',
    label: 'Charts',
    icon: <path d="M3.5 18.49l6-6.01 4 4L22 6.92l-1.41-1.41-7.09 7.97-4-4L2 16.99z" />,
  },
  {
    to: '/call-list',
    label: 'Call List',
    icon: <path d="M20 15.5c-1.25 0-2.45-.2-3.57-.57a1.02 1.02 0 00-1.02.24l-2.2 2.2a15.045 15.045 0 01-6.59-6.59l2.2-2.21a.96.96 0 00.25-1A11.36 11.36 0 018.5 4c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1 0 9.39 7.61 17 17 17 .55 0 1-.45 1-1v-3.5c0-.55-.45-1-1-1z" />,
    badgeKey: 'callList',
    badgeColor: '#ff9800',
  },
  {
    to: '/call-reports',
    label: 'Call Reports',
    icon: <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-2 10H7v-2h10v2zm0-4H7V7h10v2z" />,
  },
]

export default function Sidebar({ badges = {} }) {
  return (
    <nav className={styles.sidebar}>
      <div className={styles.header}>
        <div className={styles.logo}>
          <svg viewBox="0 0 24 24" width="20" height="20">
            <path fill="white" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
          </svg>
        </div>
        <div>
          <div className={styles.title}>HTN Monitor</div>
          <div className={styles.subtitle}>Admin Dashboard</div>
        </div>
      </div>
      <div className={styles.navSection}>
        <div className={styles.navLabel}>Main</div>
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              `${styles.navItem} ${isActive ? styles.active : ''}`
            }
          >
            <svg className={styles.navIcon} viewBox="0 0 24 24" fill="currentColor">
              {item.icon}
            </svg>
            {item.label}
            {item.badgeKey && badges[item.badgeKey] > 0 && (
              <span
                className={styles.navBadge}
                style={item.badgeColor ? { background: item.badgeColor } : undefined}
              >
                {badges[item.badgeKey]}
              </span>
            )}
          </NavLink>
        ))}
      </div>
    </nav>
  )
}
