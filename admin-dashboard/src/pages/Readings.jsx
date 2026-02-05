import { useState, useEffect } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { fetchApi } from '../api/client'
import Header from '../components/layout/Header'
import BpCategoryBadge from '../components/shared/BpCategoryBadge'
import Pagination from '../components/shared/Pagination'
import MultiSelectDropdown from '../components/shared/MultiSelectDropdown'
import DateRangeFilter from '../components/shared/DateRangeFilter'
import RangeFilter from '../components/shared/RangeFilter'
import SearchInput from '../components/shared/SearchInput'
import ExportButton from '../components/shared/ExportButton'
import { BP_CATEGORIES, classifyBP } from '../utils/bpCategory'
import styles from './Readings.module.css'

const HTN_CATEGORY_OPTIONS = ['Normal', 'Elevated', 'Stage 1', 'Stage 2', 'Crisis']

export default function Readings() {
  const [searchParams] = useSearchParams()
  const [readings, setReadings] = useState([])
  const [totalCount, setTotalCount] = useState(0)
  const [userSearch, setUserSearch] = useState('')
  const [fromDate, setFromDate] = useState('')
  const [toDate, setToDate] = useState('')
  const [offset, setOffset] = useState(0)
  const [loading, setLoading] = useState(true)

  // Multi-select filters
  const [bpCategoryFilter, setBpCategoryFilter] = useState([])
  const [unionFilter, setUnionFilter] = useState([])
  const [unions, setUnions] = useState([])

  // Range filters
  const [systolicMin, setSystolicMin] = useState(null)
  const [systolicMax, setSystolicMax] = useState(null)
  const [diastolicMin, setDiastolicMin] = useState(null)
  const [diastolicMax, setDiastolicMax] = useState(null)

  // Sort
  const [sortBy, setSortBy] = useState('reading_date')
  const [sortOrder, setSortOrder] = useState('desc')

  const limit = 15

  async function loadReadings() {
    setLoading(true)
    try {
      const params = new URLSearchParams({ limit, offset, sort_by: sortBy, sort_order: sortOrder })
      if (userSearch) params.set('user_search', userSearch)
      if (fromDate) params.set('from_date', fromDate)
      if (toDate) params.set('to_date', toDate)
      if (bpCategoryFilter.length) params.set('bp_category', bpCategoryFilter.join(','))
      if (unionFilter.length) params.set('union_id', unionFilter.join(','))
      if (systolicMin) params.set('systolic_min', systolicMin)
      if (systolicMax) params.set('systolic_max', systolicMax)
      if (diastolicMin) params.set('diastolic_min', diastolicMin)
      if (diastolicMax) params.set('diastolic_max', diastolicMax)

      const data = await fetchApi(`/admin/readings?${params}`)
      const list = data.readings || data || []
      setReadings(list)
      setTotalCount(data.total_count ?? list.length)
    } catch {
      setReadings([])
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadReadings()
  }, [offset, sortBy, sortOrder, bpCategoryFilter, unionFilter, fromDate, toDate, systolicMin, systolicMax, diastolicMin, diastolicMax])

  // Load unions for filter dropdown
  useEffect(() => {
    fetchApi('/admin/unions').then(data => {
      setUnions(data.unions || [])
    }).catch(() => {})
  }, [])

  // Read URL params for date=today
  useEffect(() => {
    if (searchParams.get('date') === 'today') {
      const today = new Date().toISOString().split('T')[0]
      setFromDate(today)
      setToDate(today)
    }
  }, [])

  function handleSearchChange(val) {
    setUserSearch(val)
    setOffset(0)
    loadReadings()
  }

  function handleClear() {
    setUserSearch('')
    setFromDate('')
    setToDate('')
    setBpCategoryFilter([])
    setUnionFilter([])
    setSystolicMin(null)
    setSystolicMax(null)
    setDiastolicMin(null)
    setDiastolicMax(null)
    setOffset(0)
    setSortBy('reading_date')
    setSortOrder('desc')
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

  async function handleExport() {
    const params = new URLSearchParams()
    if (fromDate) params.set('from_date', fromDate)
    if (toDate) params.set('to_date', toDate)
    if (unionFilter.length) params.set('union_id', unionFilter.join(','))

    const token = localStorage.getItem('token')
    const response = await fetch(`${import.meta.env.VITE_API_URL || ''}/admin/export/readings?${params}`, {
      headers: { Authorization: `Bearer ${token}` }
    })

    if (!response.ok) throw new Error('Export failed')

    const blob = await response.blob()
    const url = window.URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `readings_export_${new Date().toISOString().split('T')[0]}.csv`
    a.click()
    window.URL.revokeObjectURL(url)
  }

  function formatDate(iso) {
    if (!iso) return '\u2014'
    return new Date(iso).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      year: 'numeric',
      hour: 'numeric',
      minute: '2-digit',
    })
  }

  const unionOptions = unions.map(u => ({ value: u.id, label: u.name }))

  return (
    <>
      <Header title="Blood Pressure Readings" />

      <div className={styles.legend}>
        {BP_CATEGORIES.map((c) => (
          <div key={c.css} className={styles.legendItem}>
            <div className={styles.legendDot} style={{ background: c.color }} />
            {c.label} ({c.range})
          </div>
        ))}
      </div>

      <div className={styles.toolbar}>
        <SearchInput
          value={userSearch}
          onChange={handleSearchChange}
          placeholder="Search patient name..."
        />
        <DateRangeFilter
          label="Date Range"
          fromDate={fromDate}
          toDate={toDate}
          onChange={(from, to) => { setFromDate(from); setToDate(to); setOffset(0) }}
        />
        <MultiSelectDropdown
          label="HTN Category"
          options={HTN_CATEGORY_OPTIONS}
          selected={bpCategoryFilter}
          onChange={(v) => { setBpCategoryFilter(v); setOffset(0) }}
        />
        {unionOptions.length > 0 && (
          <MultiSelectDropdown
            label="Union"
            options={unionOptions}
            selected={unionFilter}
            onChange={(v) => { setUnionFilter(v); setOffset(0) }}
          />
        )}
        <RangeFilter
          label="Systolic"
          minValue={systolicMin}
          maxValue={systolicMax}
          onChange={(min, max) => { setSystolicMin(min); setSystolicMax(max); setOffset(0) }}
          minPlaceholder="60"
          maxPlaceholder="200"
        />
        <RangeFilter
          label="Diastolic"
          minValue={diastolicMin}
          maxValue={diastolicMax}
          onChange={(min, max) => { setDiastolicMin(min); setDiastolicMax(max); setOffset(0) }}
          minPlaceholder="40"
          maxPlaceholder="120"
        />
        <button className={styles.clearBtn} onClick={handleClear}>Clear Filters</button>
      </div>

      <div className={styles.toolbar}>
        <span className={styles.resultCount}>
          Showing {Math.min(offset + 1, totalCount)}-{Math.min(offset + limit, totalCount)} of {totalCount.toLocaleString()} readings
        </span>
        <ExportButton onClick={handleExport} label="Export CSV" />
      </div>

      <div className={styles.card}>
        {loading ? (
          <div className={styles.loading}>Loading...</div>
        ) : (
          <>
            <table className={styles.table}>
              <thead>
                <tr>
                  <th>ID</th>
                  <th>Patient</th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('systolic')}>
                    Systolic{sortArrow('systolic')}
                  </th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('diastolic')}>
                    Diastolic{sortArrow('diastolic')}
                  </th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('heart_rate')}>
                    Heart Rate{sortArrow('heart_rate')}
                  </th>
                  <th>Category</th>
                  <th className={styles.sortableHeader} onClick={() => handleSort('reading_date')}>
                    Reading Date{sortArrow('reading_date')}
                  </th>
                </tr>
              </thead>
              <tbody>
                {readings.map((r) => {
                  const cat = classifyBP(r.systolic, r.diastolic)
                  return (
                    <tr key={r.id}>
                      <td>{r.id}</td>
                      <td>
                        <Link to={`/users/${r.user_id}`} className={styles.patientLink}>
                          {r.user_name || `User #${r.user_id}`}
                        </Link>
                      </td>
                      <td className={styles[`bp${cat.css.charAt(0).toUpperCase() + cat.css.slice(1)}`]}>
                        {r.systolic}
                      </td>
                      <td className={styles[`bp${cat.css.charAt(0).toUpperCase() + cat.css.slice(1)}`]}>
                        {r.diastolic}
                      </td>
                      <td>{r.heart_rate || '\u2014'}</td>
                      <td><BpCategoryBadge systolic={r.systolic} diastolic={r.diastolic} /></td>
                      <td>{formatDate(r.reading_date)}</td>
                    </tr>
                  )
                })}
                {readings.length === 0 && (
                  <tr>
                    <td colSpan={7} style={{ textAlign: 'center', color: '#999', padding: 32 }}>
                      No readings found
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
            <Pagination offset={offset} limit={limit} total={totalCount} onChange={setOffset} />
          </>
        )}
      </div>
    </>
  )
}
