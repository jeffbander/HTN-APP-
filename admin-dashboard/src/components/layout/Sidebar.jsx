import { NavLink } from 'react-router-dom'
import { useAuth } from '../../context/AuthContext'
import styles from './Sidebar.module.css'

const ROLE_ACCENTS = {
  super_admin: '#1a73e8',
  union_leader: '#0d9488',
  shipping_company: '#d97706',
  nurse_coach: '#7c3aed',
}

const ROLE_LABELS = {
  super_admin: 'Super Admin',
  union_leader: 'Union Leader',
  shipping_company: 'Shipping',
  nurse_coach: 'Nurse Coach',
}

const allNavItems = [
  {
    to: '/dashboard',
    label: 'Dashboard',
    icon: <path d="M3 13h8V3H3v10zm0 8h8v-6H3v6zm10 0h8V11h-8v10zm0-18v6h8V3h-8z" />,
    roles: ['super_admin', 'union_leader', 'shipping_company', 'nurse_coach'],
  },
  {
    to: '/users',
    label: 'Users',
    icon: <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5z" />,
    badgeKey: 'pendingUsers',
    roles: ['super_admin'],
  },
  {
    to: '/dashboard-users',
    label: 'Dashboard Users',
    icon: <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm0 3c1.66 0 3 1.34 3 3s-1.34 3-3 3-3-1.34-3-3 1.34-3 3-3zm0 14.2a7.2 7.2 0 01-6-3.22c.03-1.99 4-3.08 6-3.08 1.99 0 5.97 1.09 6 3.08a7.2 7.2 0 01-6 3.22z" />,
    roles: ['super_admin'],
  },
  {
    to: '/readings',
    label: 'Readings',
    icon: <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zM9 17H7v-7h2v7zm4 0h-2V7h2v10zm4 0h-2v-4h2v4z" />,
    roles: ['super_admin'],
  },
  {
    to: '/charts',
    label: 'Charts',
    icon: <path d="M3.5 18.49l6-6.01 4 4L22 6.92l-1.41-1.41-7.09 7.97-4-4L2 16.99z" />,
    roles: ['super_admin'],
  },
  {
    to: '/members',
    label: 'Members',
    icon: <path d="M16 11c1.66 0 2.99-1.34 2.99-3S17.66 5 16 5c-1.66 0-3 1.34-3 3s1.34 3 3 3zm-8 0c1.66 0 2.99-1.34 2.99-3S9.66 5 8 5C6.34 5 5 6.34 5 8s1.34 3 3 3zm0 2c-2.33 0-7 1.17-7 3.5V19h14v-2.5c0-2.33-4.67-3.5-7-3.5z" />,
    roles: ['union_leader'],
  },
  {
    to: '/cuff-requests',
    label: 'Cuff Requests',
    icon: <path d="M20 8h-3V4H3c-1.1 0-2 .9-2 2v11h2c0 1.66 1.34 3 3 3s3-1.34 3-3h6c0 1.66 1.34 3 3 3s3-1.34 3-3h2v-5l-3-4zM6 18.5c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5zm13.5-9l1.96 2.5H17V9.5h2.5zm-1.5 9c-.83 0-1.5-.67-1.5-1.5s.67-1.5 1.5-1.5 1.5.67 1.5 1.5-.67 1.5-1.5 1.5z" />,
    roles: ['shipping_company'],
  },
  {
    to: '/patients',
    label: 'Patients',
    icon: <path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" />,
    roles: ['nurse_coach'],
  },
  {
    to: '/call-list',
    label: 'Call List',
    icon: <path d="M20 15.5c-1.25 0-2.45-.2-3.57-.57a1.02 1.02 0 00-1.02.24l-2.2 2.2a15.045 15.045 0 01-6.59-6.59l2.2-2.21a.96.96 0 00.25-1A11.36 11.36 0 018.5 4c0-.55-.45-1-1-1H4c-.55 0-1 .45-1 1 0 9.39 7.61 17 17 17 .55 0 1-.45 1-1v-3.5c0-.55-.45-1-1-1z" />,
    badgeKey: 'callList',
    badgeColor: '#ff9800',
    roles: ['nurse_coach', 'super_admin'],
  },
  {
    to: '/call-reports',
    label: 'Call Reports',
    icon: <path d="M19 3H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V5c0-1.1-.9-2-2-2zm-2 10H7v-2h10v2zm0-4H7V7h10v2z" />,
    roles: ['nurse_coach', 'super_admin'],
  },
  {
    to: '/flagged',
    label: 'Flagged Patients',
    icon: <path d="M14.4 6L14 4H5v17h2v-7h5.6l.4 2h7V6z" />,
    roles: ['nurse_coach'],
  },
]

export default function Sidebar({ badges = {} }) {
  const { role, userName, email } = useAuth()
  const accent = ROLE_ACCENTS[role] || '#1976d2'
  const roleLabel = ROLE_LABELS[role] || role

  const navItems = allNavItems.filter((item) => item.roles.includes(role))

  return (
    <nav className={styles.sidebar}>
      <div className={styles.header}>
        <div className={styles.logo} style={{ background: accent }}>
          <svg viewBox="0 0 24 24" width="20" height="20">
            <path fill="white" d="M12 21.35l-1.45-1.32C5.4 15.36 2 12.28 2 8.5 2 5.42 4.42 3 7.5 3c1.74 0 3.41.81 4.5 2.09C13.09 3.81 14.76 3 16.5 3 19.58 3 22 5.42 22 8.5c0 3.78-3.4 6.86-8.55 11.54L12 21.35z" />
          </svg>
        </div>
        <div>
          <div className={styles.title}>HTN Monitor</div>
          <div className={styles.subtitle}>{roleLabel}</div>
        </div>
      </div>
      <div className={styles.userInfo}>
        <div className={styles.userName}>{userName || email}</div>
        <span className={styles.roleBadge} style={{ background: accent }}>
          {roleLabel}
        </span>
      </div>
      <div className={styles.navSection}>
        <div className={styles.navLabel}>Navigation</div>
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            className={({ isActive }) =>
              `${styles.navItem} ${isActive ? styles.active : ''}`
            }
            style={({ isActive }) =>
              isActive
                ? { background: `${accent}22`, color: accent, borderRightColor: accent }
                : undefined
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
