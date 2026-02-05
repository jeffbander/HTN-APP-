import { useState, useEffect, useCallback } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './context/AuthContext'
import { fetchApi } from './api/client'
import AppLayout from './components/layout/AppLayout'
import Login from './pages/Login'
import MfaVerify from './pages/MfaVerify'
import MfaSetup from './pages/MfaSetup'
import Dashboard from './pages/Dashboard'
import Users from './pages/Users'
import Readings from './pages/Readings'
import Charts from './pages/Charts'
import CallList from './pages/CallList'
import CallReports from './pages/CallReports'
import PatientDetail from './pages/PatientDetail'

function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth()
  if (!isAuthenticated) return <Navigate to="/login" replace />
  return children
}

export default function App() {
  const { isAuthenticated } = useAuth()
  const [badges, setBadges] = useState({})

  const loadBadges = useCallback(async () => {
    try {
      const data = await fetchApi('/admin/stats')
      setBadges({
        pendingUsers: data.pending_approvals || 0,
      })
    } catch {
      // ignore
    }
  }, [])

  useEffect(() => {
    if (!isAuthenticated) return
    loadBadges()
    const interval = setInterval(loadBadges, 60000)
    return () => clearInterval(interval)
  }, [isAuthenticated, loadBadges])

  return (
    <Routes>
      <Route path="/login" element={<Login />} />
      <Route path="/mfa-verify" element={<MfaVerify />} />
      <Route path="/mfa-setup" element={<MfaSetup />} />
      <Route
        element={
          <ProtectedRoute>
            <AppLayout badges={badges} />
          </ProtectedRoute>
        }
      >
        <Route path="/dashboard" element={<Dashboard />} />
        <Route path="/users" element={<Users />} />
        <Route path="/users/:id" element={<PatientDetail />} />
        <Route path="/readings" element={<Readings />} />
        <Route path="/charts" element={<Charts />} />
        <Route path="/call-list" element={<CallList />} />
        <Route path="/call-reports" element={<CallReports />} />
      </Route>
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  )
}
