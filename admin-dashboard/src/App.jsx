import { useState } from 'react'
import { Routes, Route, Navigate } from 'react-router-dom'
import { useAuth } from './context/AuthContext'
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
import DashboardUsers from './pages/SuperAdmin/DashboardUsers'
import Members from './pages/UnionLeader/Members'
import CuffRequests from './pages/Shipping/CuffRequests'
import Patients from './pages/NurseCoach/Patients'
import FlaggedPatients from './pages/NurseCoach/FlaggedPatients'

function ProtectedRoute({ children }) {
  const { isAuthenticated } = useAuth()
  if (!isAuthenticated) return <Navigate to="/login" replace />
  return children
}

function RoleRoute({ children, allowed }) {
  const { isAuthenticated, role } = useAuth()
  if (!isAuthenticated) return <Navigate to="/login" replace />
  if (!allowed.includes(role)) return <Navigate to="/dashboard" replace />
  return children
}

function SuperAdminRoute({ children }) {
  return <RoleRoute allowed={['super_admin']}>{children}</RoleRoute>
}

function UnionLeaderRoute({ children }) {
  return <RoleRoute allowed={['union_leader', 'super_admin']}>{children}</RoleRoute>
}

function ShippingRoute({ children }) {
  return <RoleRoute allowed={['shipping_company', 'super_admin']}>{children}</RoleRoute>
}

function NurseCoachRoute({ children }) {
  return <RoleRoute allowed={['nurse_coach', 'super_admin']}>{children}</RoleRoute>
}

export default function App() {
  const { isAuthenticated } = useAuth()
  const [badges] = useState({})

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
        {/* Shared */}
        <Route path="/dashboard" element={<Dashboard />} />

        {/* Super Admin only */}
        <Route path="/users" element={<SuperAdminRoute><Users /></SuperAdminRoute>} />
        <Route path="/users/:id" element={<SuperAdminRoute><PatientDetail /></SuperAdminRoute>} />
        <Route path="/readings" element={<SuperAdminRoute><Readings /></SuperAdminRoute>} />
        <Route path="/charts" element={<SuperAdminRoute><Charts /></SuperAdminRoute>} />
        <Route path="/dashboard-users" element={<SuperAdminRoute><DashboardUsers /></SuperAdminRoute>} />

        {/* Union Leader */}
        <Route path="/members" element={<UnionLeaderRoute><Members /></UnionLeaderRoute>} />

        {/* Shipping */}
        <Route path="/cuff-requests" element={<ShippingRoute><CuffRequests /></ShippingRoute>} />

        {/* Nurse Coach */}
        <Route path="/patients" element={<NurseCoachRoute><Patients /></NurseCoachRoute>} />
        <Route path="/patients/:id" element={<NurseCoachRoute><PatientDetail /></NurseCoachRoute>} />
        <Route path="/flagged" element={<NurseCoachRoute><FlaggedPatients /></NurseCoachRoute>} />
        <Route path="/call-list" element={<NurseCoachRoute><CallList /></NurseCoachRoute>} />
        <Route path="/call-reports" element={<NurseCoachRoute><CallReports /></NurseCoachRoute>} />
      </Route>
      <Route path="/" element={<Navigate to="/dashboard" replace />} />
      <Route path="*" element={<Navigate to="/dashboard" replace />} />
    </Routes>
  )
}
