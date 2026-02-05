import { useState, useEffect, useRef, useCallback } from 'react'
import { Link, useSearchParams, useNavigate } from 'react-router-dom'
import { fetchApi } from '../api/client'
import Header from '../components/layout/Header'
import Badge from '../components/shared/Badge'
import Pagination from '../components/shared/Pagination'
import Modal from '../components/shared/Modal'
import MultiSelectDropdown from '../components/shared/MultiSelectDropdown'
import DateRangeFilter from '../components/shared/DateRangeFilter'
import RangeFilter from '../components/shared/RangeFilter'
import SearchInput from '../components/shared/SearchInput'
import BulkSelectionBar from '../components/shared/BulkSelectionBar'
import ExportButton from '../components/shared/ExportButton'
import styles from './Users.module.css'

const STATUS_OPTIONS = [
  { value: 'all', label: 'All Users' },
  { value: 'pending', label: 'Pending Approval' },
  { value: 'approved', label: 'Approved' },
  { value: 'deactivated', label: 'Deactivated' },
]

const GENDER_OPTIONS = ['Male', 'Female', 'Prefer not to say']
const RANK_OPTIONS = ['Lieutenant', 'Captain', 'Battalion Chief', 'Firefighter', 'Fire Alarm Dispatcher', 'Deputy Chief', 'Other']
const WORK_STATUS_OPTIONS = ['Active', 'Retired']
const CHRONIC_CONDITIONS_OPTIONS = [
  'Diabetes',
  'Heart Disease',
  'Kidney Disease',
  'Stroke',
  'High Cholesterol',
  'Sleep Apnea',
  'Obesity',
  'None'
]

export default function Users() {
  const navigate = useNavigate()
  const [searchParams] = useSearchParams()
  const [users, setUsers] = useState([])
  const [totalCount, setTotalCount] = useState(0)
  const [stats, setStats] = useState(null)
  const [status, setStatus] = useState(searchParams.get('status') || 'all')
  const [search, setSearch] = useState('')
  const [offset, setOffset] = useState(0)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState(null)
  const [modal, setModal] = useState(null)
  const [sortBy, setSortBy] = useState('created_at')
  const [sortOrder, setSortOrder] = useState('desc')

  // Multi-select filter states
  const [genderFilter, setGenderFilter] = useState([])
  const [rankFilter, setRankFilter] = useState([])
  const [workStatusFilter, setWorkStatusFilter] = useState([])
  const [unionFilter, setUnionFilter] = useState([])
  const [chronicConditionsFilter, setChronicConditionsFilter] = useState([])

  // Age range filter
  const [ageMin, setAgeMin] = useState(null)
  const [ageMax, setAgeMax] = useState(null)

  // Date registered filter
  const [registeredFrom, setRegisteredFrom] = useState('')
  const [registeredTo, setRegisteredTo] = useState('')

  // Unions list for filter dropdown
  const [unions, setUnions] = useState([])

  // Bulk selection
  const [selectedIds, setSelectedIds] = useState(new Set())
  const [bulkLoading, setBulkLoading] = useState(false)

  const limit = 15

  const loadUsers = useCallback(async (searchVal) => {
    setLoading(true)
    setError(null)
    try {
      const params = new URLSearchParams({ limit, offset, sort_by: sortBy, sort_order: sortOrder })
      if (status !== 'all') params.set('status', status)
      if (searchVal) params.set('search', searchVal)
      if (genderFilter.length) params.set('gender', genderFilter.join(','))
      if (rankFilter.length) params.set('rank', rankFilter.join(','))
      if (workStatusFilter.length) params.set('work_status', workStatusFilter.join(','))
      if (unionFilter.length) params.set('union_id', unionFilter.join(','))
      if (ageMin) params.set('age_min', ageMin)
      if (ageMax) params.set('age_max', ageMax)
      if (registeredFrom) params.set('registered_from', registeredFrom)
      if (registeredTo) params.set('registered_to', registeredTo)

      const data = await fetchApi(`/admin/users?${params}`)
      const list = data.users || data || []
      setUsers(list)
      setTotalCount(data.total_count ?? list.length)
    } catch (err) {
      setError(err.message || 'Failed to load users')
      setUsers([])
    } finally {
      setLoading(false)
    }
  }, [status, offset, sortBy, sortOrder, genderFilter, rankFilter, workStatusFilter, unionFilter, ageMin, ageMax, registeredFrom, registeredTo])

  useEffect(() => {
    loadUsers(search)
  }, [status, offset, sortBy, sortOrder, genderFilter, rankFilter, workStatusFilter, unionFilter, ageMin, ageMax, registeredFrom, registeredTo])

  // Load stats for the stat cards
  useEffect(() => {
    fetchApi('/admin/stats').then(setStats).catch(() => {})
  }, [])

  // Load unions for filter dropdown
  useEffect(() => {
    fetchApi('/admin/unions').then(data => {
      setUnions(data.unions || [])
    }).catch(() => {})
  }, [])

  // Read URL params on mount
  useEffect(() => {
    const urlStatus = searchParams.get('status')
    if (urlStatus && STATUS_OPTIONS.some((o) => o.value === urlStatus)) {
      setStatus(urlStatus)
    }
  }, [])

  function handleSearchChange(val) {
    setSearch(val)
    setOffset(0)
    loadUsers(val)
  }

  function handleSort(col) {
    if (sortBy === col) {
      setSortOrder(sortOrder === 'asc' ? 'desc' : 'asc')
    } else {
      setSortBy(col)
      setSortOrder('asc')
    }
    setOffset(0)
  }

  function sortArrow(col) {
    if (sortBy !== col) return ''
    return sortOrder === 'asc' ? ' \u25B2' : ' \u25BC'
  }

  function userStatus(u) {
    if (!u.is_active) return { label: 'Deactivated', color: 'red' }
    if (!u.is_approved) return { label: 'Pending', color: 'orange' }
    return { label: 'Approved', color: 'green' }
  }

  async function handleApprove(user) {
    try {
      await fetchApi(`/admin/users/${user.id}/approve`, { method: 'PUT' })
      setModal(null)
      loadUsers(search)
    } catch (err) {
      alert(err.message)
    }
  }

  async function handleDeactivate(user) {
    try {
      await fetchApi(`/admin/users/${user.id}/deactivate`, { method: 'PUT' })
      setModal(null)
      loadUsers(search)
    } catch (err) {
      alert(err.message)
    }
  }

  // Bulk operations
  function toggleSelect(id) {
    const next = new Set(selectedIds)
    if (next.has(id)) {
      next.delete(id)
    } else {
      next.add(id)
    }
    setSelectedIds(next)
  }

  function selectAll() {
    setSelectedIds(new Set(users.map(u => u.id)))
  }

  function deselectAll() {
    setSelectedIds(new Set())
  }

  async function handleBulkApprove() {
    if (selectedIds.size === 0) return
    setBulkLoading(true)
    try {
      const result = await fetchApi('/admin/users/bulk-approve', {
        method: 'POST',
        body: JSON.stringify({ user_ids: Array.from(selectedIds) })
      })
      alert(`Approved ${result.results.success.length} users. ${result.results.skipped.length} skipped. ${result.results.error.length} errors.`)
      setSelectedIds(new Set())
      loadUsers(search)
    } catch (err) {
      alert(err.message)
    } finally {
      setBulkLoading(false)
    }
  }

  async function handleBulkDeactivate() {
    if (selectedIds.size === 0) return
    setBulkLoading(true)
    try {
      const result = await fetchApi('/admin/users/bulk-deactivate', {
        method: 'POST',
        body: JSON.stringify({ user_ids: Array.from(selectedIds) })
      })
      alert(`Deactivated ${result.results.success.length} users. ${result.results.skipped.length} skipped. ${result.results.error.length} errors.`)
      setSelectedIds(new Set())
      loadUsers(search)
    } catch (err) {
      alert(err.message)
    } finally {
      setBulkLoading(false)
    }
  }

  async function handleExport() {
    const params = new URLSearchParams()
    if (status !== 'all') params.set('status', status)
    if (genderFilter.length) params.set('gender', genderFilter.join(','))
    if (rankFilter.length) params.set('rank', rankFilter.join(','))
    if (workStatusFilter.length) params.set('work_status', workStatusFilter.join(','))
    if (unionFilter.length) params.set('union_id', unionFilter.join(','))
    if (ageMin) params.set('age_min', ageMin)
    if (ageMax) params.set('age_max', ageMax)
    if (registeredFrom) params.set('registered_from', registeredFrom)
    if (registeredTo) params.set('registered_to', registeredTo)

    const token = localStorage.getItem('token')
    const response = await fetch(`${import.meta.env.VITE_API_URL || ''}/admin/export/users?${params}`, {
      headers: { Authorization: `Bearer ${token}` }
    })

    if (!response.ok) throw new Error('Export failed')

    const blob = await response.blob()
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `users_export_${new Date().toISOString().split('T')[0]}.csv`
    a.click()
    window.URL.revokeObjectURL(url)
  }

  function formatDate(iso) {
    if (!iso) return '\u2014'
    return new Date(iso).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
    })
  }

  const unionOptions = unions.map(u => ({ value: u.id, label: u.name }))

  return (
    <>
      <Header title="User Management" />

      {/* Stat cards */}
      {stats && (
        <div className={styles.statsRow}>
          <div className={styles.miniStat}>
            <div className={styles.miniStatLabel}>Total</div>
            <div className={styles.miniStatValue}>{stats.total_users}</div>
          </div>
          <div className={styles.miniStat}>
            <div className={styles.miniStatLabel}>Pending</div>
            <div className={styles.miniStatValue} style={{ color: '#ef6c00' }}>{stats.pending_approvals}</div>
          </div>
          <div className={styles.miniStat}>
            <div className={styles.miniStatLabel}>Approved</div>
            <div className={styles.miniStatValue} style={{ color: '#2e7d32' }}>{stats.approved_users}</div>
          </div>
          <div className={styles.miniStat}>
            <div className={styles.miniStatLabel}>Deactivated</div>
            <div className={styles.miniStatValue} style={{ color: '#c62828' }}>{stats.deactivated_users}</div>
          </div>
        </div>
      )}

      <div className={styles.toolbar}>
        <div className={styles.filterGroup}>
          <span className={styles.filterLabel}>Status:</span>
          <select
            value={status}
            onChange={(e) => { setStatus(e.target.value); setOffset(0) }}
            className={styles.select}
          >
            {STATUS_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>{o.label}</option>
            ))}
          </select>
        </div>

        <MultiSelectDropdown
          label="Gender"
          options={GENDER_OPTIONS}
          selected={genderFilter}
          onChange={(v) => { setGenderFilter(v); setOffset(0) }}
        />
        <MultiSelectDropdown
          label="Rank"
          options={RANK_OPTIONS}
          selected={rankFilter}
          onChange={(v) => { setRankFilter(v); setOffset(0) }}
        />
        <MultiSelectDropdown
          label="Work Status"
          options={WORK_STATUS_OPTIONS}
          selected={workStatusFilter}
          onChange={(v) => { setWorkStatusFilter(v); setOffset(0) }}
        />
        {unionOptions.length > 0 && (
          <MultiSelectDropdown
            label="Union"
            options={unionOptions}
            selected={unionFilter}
            onChange={(v) => { setUnionFilter(v); setOffset(0) }}
          />
        )}
        <MultiSelectDropdown
          label="Conditions"
          options={CHRONIC_CONDITIONS_OPTIONS}
          selected={chronicConditionsFilter}
          onChange={(v) => { setChronicConditionsFilter(v); setOffset(0) }}
        />
        <RangeFilter
          label="Age"
          minValue={ageMin}
          maxValue={ageMax}
          onChange={(min, max) => { setAgeMin(min); setAgeMax(max); setOffset(0) }}
          minPlaceholder="18"
          maxPlaceholder="100"
          unit="yrs"
        />
        <DateRangeFilter
          label="Registered"
          fromDate={registeredFrom}
          toDate={registeredTo}
          onChange={(from, to) => { setRegisteredFrom(from); setRegisteredTo(to); setOffset(0) }}
        />
      </div>

      <div className={styles.toolbar}>
        <SearchInput
          value={search}
          onChange={handleSearchChange}
          placeholder="Search by name or email..."
        />
        <span className={styles.resultCount}>
          Showing {users.length} of {totalCount} users
        </span>
        <ExportButton onClick={handleExport} label="Export CSV" />
      </div>

      {error && (
        <div className={styles.errorBanner}>
          Failed to load users: {error}
          <button className={styles.retryBtn} onClick={() => loadUsers(search)}>Retry</button>
        </div>
      )}

      <div className={styles.card}>
        {loading ? (
          <div className={styles.loading}>Loading...</div>
        ) : (
          <>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th style={{ width: 40 }}>
                    <input
                      type="checkbox"
                      checked={selectedIds.size === users.length && users.length > 0}
                      onChange={(e) => e.target.checked ? selectAll() : deselectAll()}
                    />
                  </th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('id')}>
                    ID{sortArrow('id')}
                  </th>
                  <th>Name</th>
                  <th>Email</th>
                  <th>Union</th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('gender')}>
                    Gender{sortArrow('gender')}
                  </th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('rank')}>
                    Rank{sortArrow('rank')}
                  </th>
                  <th>Status</th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('created_at')}>
                    Registered{sortArrow('created_at')}
                  </th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {users.map((u) => {
                  const st = userStatus(u)
                  return (
                    <tr key={u.id} className={styles.clickableRow} onClick={() => navigate(`/users/${u.id}`)}>
                      <td onClick={(e) => e.stopPropagation()}>
                        <input
                          type="checkbox"
                          checked={selectedIds.has(u.id)}
                          onChange={() => toggleSelect(u.id)}
                        />
                      </td>
                      <td>{u.id}</td>
                      <td>
                        <Link to={`/users/${u.id}`} className={styles.nameLink} onClick={(e) => e.stopPropagation()}>
                          {u.name || '\u2014'}
                        </Link>
                      </td>
                      <td>{u.email || '\u2014'}</td>
                      <td>{u.union_name || `Union #${u.union_id || '\u2014'}`}</td>
                      <td>{u.gender || '\u2014'}</td>
                      <td>{u.rank || '\u2014'}</td>
                      <td><Badge color={st.color}>{st.label}</Badge></td>
                      <td>{formatDate(u.created_at)}</td>
                      <td onClick={(e) => e.stopPropagation()}>
                        {!u.is_active ? (
                          <button className={`${styles.actionBtn} ${styles.btnDisabled}`} disabled>
                            Deactivated
                          </button>
                        ) : !u.is_approved ? (
                          <button
                            className={`${styles.actionBtn} ${styles.btnApprove}`}
                            onClick={() => setModal({ type: 'approve', user: u })}
                          >
                            Approve
                          </button>
                        ) : (
                          <button
                            className={`${styles.actionBtn} ${styles.btnDeactivate}`}
                            onClick={() => setModal({ type: 'deactivate', user: u })}
                          >
                            Deactivate
                          </button>
                        )}
                      </td>
                    </tr>
                  )
                })}
                {users.length === 0 && !error && (
                  <tr>
                    <td colSpan={10} style={{ textAlign: 'center', color: '#999', padding: 32 }}>
                      No users found
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
            <Pagination offset={offset} limit={limit} total={totalCount} onChange={setOffset} />
          </>
        )}
      </div>

      <BulkSelectionBar
        selectedCount={selectedIds.size}
        totalCount={users.length}
        onSelectAll={selectAll}
        onDeselectAll={deselectAll}
        loading={bulkLoading}
        actions={[
          { label: 'Approve Selected', onClick: handleBulkApprove, icon: '✓' },
          { label: 'Deactivate Selected', onClick: handleBulkDeactivate, variant: 'danger', icon: '✕' },
        ]}
      />

      <Modal
        open={modal?.type === 'approve'}
        title="Approve User"
        confirmLabel="Approve User"
        confirmColor="#4caf50"
        onCancel={() => setModal(null)}
        onConfirm={() => handleApprove(modal.user)}
      >
        <p>
          Are you sure you want to approve <strong>{modal?.user?.name}</strong> ({modal?.user?.email})?
          They will be able to log in and submit blood pressure readings.
        </p>
      </Modal>

      <Modal
        open={modal?.type === 'deactivate'}
        title="Deactivate User"
        confirmLabel="Deactivate User"
        confirmColor="#f44336"
        onCancel={() => setModal(null)}
        onConfirm={() => handleDeactivate(modal.user)}
      >
        <p>
          Are you sure you want to deactivate <strong>{modal?.user?.name}</strong> ({modal?.user?.email})?
          They will no longer be able to log in.
        </p>
      </Modal>
    </>
  )
}
