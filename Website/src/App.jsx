import React, { useState, useEffect, useRef } from 'react';
import { generateClient } from 'aws-amplify/api';
import { MapContainer, TileLayer, Marker, Popup, useMap } from 'react-leaflet';
import { AlertTriangle, MapPin, Phone, Clock, ShieldCheck, Lock, LogOut, Activity, Trash2 } from 'lucide-react';
import 'leaflet/dist/leaflet.css';

// Fix for Leaflet marker icons in React
import L from 'leaflet';
import icon from 'leaflet/dist/images/marker-icon.png';
import iconShadow from 'leaflet/dist/images/marker-shadow.png';

let DefaultIcon = L.icon({
    iconUrl: icon,
    shadowUrl: iconShadow,
    iconSize: [25, 41],
    iconAnchor: [12, 41]
});
L.Marker.prototype.options.icon = DefaultIcon;

const client = generateClient();

// ─── GraphQL Queries ────────────────────────────────────────────

const getSOSSession = /* GraphQL */ `
  query GetSOSSession($id: ID!) {
    getSOSSession(id: $id) {
      id
      phoneNumber
      latitude
      longitude
      isActive
      updatedAt
      createdAt
    }
  }
`;

const listAllSOSSessions = /* GraphQL */ `
  query ListSOSSessions {
    listSOSSessions {
      items {
        id
        phoneNumber
        latitude
        longitude
        isActive
        updatedAt
        createdAt
      }
    }
  }
`;

const deleteSOSSessionMutation = /* GraphQL */ `
  mutation DeleteSOSSession($input: DeleteSOSSessionInput!) {
    deleteSOSSession(input: $input) {
      id
    }
  }
`;

// ─── Helper: Map Recentering ────────────────────────────────────

function RecenterMap({ lat, lng }) {
    const map = useMap();
    useEffect(() => {
        map.flyTo([lat, lng], 15, { animate: true, duration: 1.5 });
    }, [lat, lng, map]);
    return null;
}

// ─── Session Ended Overlay ──────────────────────────────────────

function SessionEndedOverlay({ session }) {
    return (
        <div className="fixed inset-0 z-[9999] flex items-center justify-center bg-slate-900/60 backdrop-blur-sm">
            <div className="bg-white rounded-3xl shadow-2xl p-10 max-w-md w-full mx-4 text-center animate-fade-in">
                <div className="mx-auto w-20 h-20 rounded-full bg-green-100 flex items-center justify-center mb-6">
                    <ShieldCheck className="w-10 h-10 text-green-600" />
                </div>
                <h2 className="text-2xl font-bold text-slate-900 mb-2">SOS Session Ended</h2>
                <p className="text-slate-500 mb-2">The user has stopped the emergency alert.</p>
                {session && (
                    <p className="text-sm text-slate-400 mb-6">
                        Last known location: {session.latitude?.toFixed(6)}, {session.longitude?.toFixed(6)}
                    </p>
                )}
                {session?.phoneNumber && (
                    <a
                        href={`tel:${session.phoneNumber}`}
                        className="flex items-center justify-center w-full py-3 bg-slate-900 text-white rounded-xl hover:bg-slate-800 transition-all font-semibold"
                    >
                        <Phone className="w-4 h-4 mr-2" /> Call {session.phoneNumber}
                    </a>
                )}
            </div>
        </div>
    );
}

// ═══════════════════════════════════════════════════════════════════
// TRACKING PAGE — opened via ?session=<ID> link from SMS
// Only shows the specific session's map and info. No dashboard.
// ═══════════════════════════════════════════════════════════════════

function TrackingPage({ sessionId }) {
    const [session, setSession] = useState(null);
    const [loading, setLoading] = useState(true);
    const [ended, setEnded] = useState(false);

    const fetchSession = async () => {
        try {
            const result = await client.graphql({
                query: getSOSSession,
                variables: { id: sessionId },
                authMode: 'apiKey'
            });
            const s = result.data.getSOSSession;
            if (s) {
                setSession(s);
                if (!s.isActive && !ended) {
                    setEnded(true);
                }
            }
        } catch (err) {
            console.error("Error fetching session:", err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchSession();
        const interval = setInterval(fetchSession, 5000);
        return () => clearInterval(interval);
    }, [sessionId]);

    if (loading) {
        return (
            <div className="min-h-screen bg-slate-50 flex items-center justify-center">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-red-500"></div>
            </div>
        );
    }

    if (!session) {
        return (
            <div className="min-h-screen bg-slate-50 flex items-center justify-center">
                <div className="text-center">
                    <AlertTriangle className="w-16 h-16 text-slate-300 mx-auto mb-4" />
                    <h2 className="text-xl font-bold text-slate-700">Session Not Found</h2>
                    <p className="text-slate-500 mt-2">This tracking link may have expired.</p>
                </div>
            </div>
        );
    }

    return (
        <div className="min-h-screen bg-slate-50">
            {ended && <SessionEndedOverlay session={session} />}

            {/* Header */}
            <header className="bg-white shadow-sm border-b border-slate-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <div className="bg-red-500 p-1.5 rounded-lg">
                            <AlertTriangle className="w-5 h-5 text-white animate-pulse" />
                        </div>
                        <h1 className="text-lg font-bold text-slate-900">Suraksha+ Live Tracking</h1>
                    </div>
                    <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-bold ${session.isActive
                        ? 'bg-red-100 text-red-700 border border-red-200'
                        : 'bg-green-100 text-green-700 border border-green-200'
                        }`}>
                        <span className={`w-2 h-2 rounded-full mr-2 ${session.isActive ? 'bg-red-500 animate-pulse' : 'bg-green-500'}`}></span>
                        {session.isActive ? 'SOS ACTIVE' : 'ENDED'}
                    </span>
                </div>
            </header>

            <main className="max-w-7xl mx-auto px-4 py-4">
                <div className="flex flex-col lg:grid lg:grid-cols-3 gap-4 lg:h-[calc(100vh-120px)]">
                    {/* Info Card */}
                    <div className="lg:col-span-1">
                        <div className="bg-white rounded-2xl shadow-lg border border-slate-100 p-5 relative overflow-hidden">
                            <div className="absolute top-0 right-0 p-3 opacity-10">
                                <AlertTriangle className="w-24 h-24 text-red-500" />
                            </div>
                            <div className="relative z-10">
                                <h2 className="text-2xl font-bold text-slate-900 mb-1">{session.phoneNumber}</h2>
                                <p className="text-slate-500 text-sm mb-5">
                                    {session.isActive ? 'User needs immediate assistance' : 'Alert has been stopped'}
                                </p>

                                <div className="space-y-3">
                                    <div className="flex items-center p-3 bg-slate-50 rounded-xl border border-slate-100">
                                        <div className="bg-blue-100 p-2 rounded-lg mr-3">
                                            <MapPin className="w-4 h-4 text-blue-600" />
                                        </div>
                                        <div>
                                            <p className="text-xs text-slate-500 font-semibold uppercase">Location</p>
                                            <p className="font-mono text-sm">{session.latitude?.toFixed(6)}, {session.longitude?.toFixed(6)}</p>
                                        </div>
                                    </div>

                                    <div className="flex items-center p-3 bg-slate-50 rounded-xl border border-slate-100">
                                        <div className="bg-orange-100 p-2 rounded-lg mr-3">
                                            <Clock className="w-4 h-4 text-orange-600" />
                                        </div>
                                        <div>
                                            <p className="text-xs text-slate-500 font-semibold uppercase">Last Updated</p>
                                            <p className="font-mono text-sm">{new Date(session.updatedAt).toLocaleTimeString()}</p>
                                        </div>
                                    </div>
                                </div>

                                <div className="mt-6 pt-4 border-t border-slate-100">
                                    <a
                                        href={`tel:${session.phoneNumber}`}
                                        className="flex items-center justify-center w-full py-3 bg-slate-900 text-white rounded-xl hover:bg-slate-800 transition-all font-semibold shadow-lg"
                                    >
                                        <Phone className="w-4 h-4 mr-2" /> Call User
                                    </a>
                                </div>
                            </div>
                        </div>
                    </div>

                    {/* Map */}
                    <div className="lg:col-span-2 bg-white rounded-2xl shadow-lg border border-slate-100 overflow-hidden relative min-h-[60vh] lg:min-h-0">
                        <MapContainer
                            center={[session.latitude, session.longitude]}
                            zoom={15}
                            scrollWheelZoom={true}
                            className="h-full w-full"
                            style={{ minHeight: '60vh' }}
                        >
                            <TileLayer
                                attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                                url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                            />
                            <Marker position={[session.latitude, session.longitude]}>
                                <Popup>
                                    {session.phoneNumber}<br />
                                    {session.latitude?.toFixed(6)}, {session.longitude?.toFixed(6)}
                                </Popup>
                            </Marker>
                            <RecenterMap lat={session.latitude} lng={session.longitude} />
                        </MapContainer>
                        <div className="absolute top-0 left-0 right-0 h-20 bg-gradient-to-b from-black/10 to-transparent pointer-events-none z-[400]"></div>
                    </div>
                </div>
            </main>
        </div>
    );
}

// ═══════════════════════════════════════════════════════════════════
// ADMIN DASHBOARD — main page, password-protected
// Shows all SOS sessions (active + ended)
// ═══════════════════════════════════════════════════════════════════

const ADMIN_PASSWORD = "suraksha@admin";

function AdminLogin({ onLogin }) {
    const [password, setPassword] = useState('');
    const [error, setError] = useState('');
    const [showPassword, setShowPassword] = useState(false);

    const handleSubmit = (e) => {
        e.preventDefault();
        if (password === ADMIN_PASSWORD) {
            sessionStorage.setItem('admin_auth', 'true');
            onLogin();
        } else {
            setError('Incorrect password');
            setTimeout(() => setError(''), 3000);
        }
    };

    return (
        <div className="min-h-screen bg-slate-900 flex items-center justify-center p-4">
            <div className="bg-white rounded-3xl shadow-2xl p-8 max-w-sm w-full animate-fade-in">
                <div className="text-center mb-8">
                    <div className="mx-auto w-16 h-16 rounded-full bg-slate-100 flex items-center justify-center mb-4">
                        <Lock className="w-8 h-8 text-slate-600" />
                    </div>
                    <h1 className="text-2xl font-bold text-slate-900">Admin Access</h1>
                    <p className="text-slate-500 text-sm mt-1">Suraksha+ Control Panel</p>
                </div>

                <form onSubmit={handleSubmit} className="space-y-4">
                    <div className="relative">
                        <input
                            type={showPassword ? 'text' : 'password'}
                            value={password}
                            onChange={(e) => setPassword(e.target.value)}
                            placeholder="Enter admin password"
                            className="w-full px-4 py-3 pr-12 rounded-xl border border-slate-200 focus:border-slate-900 focus:ring-2 focus:ring-slate-900/10 outline-none transition-all text-center text-lg tracking-widest"
                            autoFocus
                        />
                        <button
                            type="button"
                            onClick={() => setShowPassword(!showPassword)}
                            className="absolute right-3 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-700 transition-colors p-1"
                        >
                            {showPassword ? (
                                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" /><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" /><line x1="1" y1="1" x2="23" y2="23" /></svg>
                            ) : (
                                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" /></svg>
                            )}
                        </button>
                    </div>
                    {error && (
                        <p className="text-red-500 text-sm text-center font-medium">{error}</p>
                    )}
                    <button
                        type="submit"
                        className="w-full py-3 bg-slate-900 text-white rounded-xl hover:bg-slate-800 transition-all font-semibold"
                    >
                        Login
                    </button>
                </form>
            </div>
        </div>
    );
}

function AdminDashboard() {
    const [sessions, setSessions] = useState([]);
    const [selectedSession, setSelectedSession] = useState(null);
    const [loading, setLoading] = useState(true);
    const [filter, setFilter] = useState('all'); // 'all', 'active', 'ended'

    const fetchSessions = async () => {
        try {
            const result = await client.graphql({
                query: listAllSOSSessions,
                authMode: 'apiKey'
            });
            const items = result.data.listSOSSessions.items;
            // Sort: active first, then by updatedAt descending
            items.sort((a, b) => {
                if (a.isActive !== b.isActive) return a.isActive ? -1 : 1;
                return new Date(b.updatedAt) - new Date(a.updatedAt);
            });
            setSessions(items);

            // Update selected session if viewing one
            if (selectedSession) {
                const updated = items.find(s => s.id === selectedSession.id);
                if (updated) setSelectedSession(updated);
            }
        } catch (err) {
            console.error("Error fetching sessions:", err);
        } finally {
            setLoading(false);
        }
    };

    useEffect(() => {
        fetchSessions();
        const interval = setInterval(fetchSessions, 5000);
        return () => clearInterval(interval);
    }, []);

    const handleLogout = () => {
        sessionStorage.removeItem('admin_auth');
        window.location.reload();
    };

    const deleteSession = async (e, sessionId) => {
        e.stopPropagation();
        if (!window.confirm('Are you sure you want to delete this SOS session?')) return;
        try {
            await client.graphql({
                query: deleteSOSSessionMutation,
                variables: { input: { id: sessionId } },
                authMode: 'apiKey'
            });
            setSessions(prev => prev.filter(s => s.id !== sessionId));
            if (selectedSession?.id === sessionId) setSelectedSession(null);
        } catch (err) {
            console.error('Delete failed:', err);
            alert('Failed to delete session');
        }
    };

    const filteredSessions = sessions.filter(s => {
        if (filter === 'active') return s.isActive;
        if (filter === 'ended') return !s.isActive;
        return true;
    });

    const activeSessions = sessions.filter(s => s.isActive);
    const endedSessions = sessions.filter(s => !s.isActive);

    // Detail view for a selected session
    if (selectedSession) {
        return (
            <div className="min-h-screen bg-slate-50">
                <header className="bg-white shadow-sm border-b border-slate-200 sticky top-0 z-50">
                    <div className="max-w-7xl mx-auto px-4 h-14 flex items-center justify-between">
                        <button
                            onClick={() => setSelectedSession(null)}
                            className="flex items-center text-slate-500 hover:text-slate-900 transition-colors font-medium"
                        >
                            ← Back to Admin
                        </button>
                        <span className={`inline-flex items-center px-3 py-1 rounded-full text-xs font-bold ${selectedSession.isActive
                            ? 'bg-red-100 text-red-700'
                            : 'bg-green-100 text-green-700'
                            }`}>
                            {selectedSession.isActive ? 'ACTIVE' : 'ENDED'}
                        </span>
                    </div>
                </header>

                <main className="max-w-7xl mx-auto px-4 py-4">
                    <div className="flex flex-col lg:grid lg:grid-cols-3 gap-4 lg:h-[calc(100vh-120px)]">
                        <div className="lg:col-span-1">
                            <div className="bg-white rounded-2xl shadow-lg border border-slate-100 p-5 relative overflow-hidden">
                                <div className="relative z-10">
                                    <h2 className="text-2xl font-bold text-slate-900 mb-1">{selectedSession.phoneNumber}</h2>
                                    <p className="text-slate-500 text-sm mb-5">
                                        Started: {new Date(selectedSession.createdAt).toLocaleString()}
                                    </p>

                                    <div className="space-y-3">
                                        <div className="flex items-center p-3 bg-slate-50 rounded-xl border border-slate-100">
                                            <div className="bg-blue-100 p-2 rounded-lg mr-3">
                                                <MapPin className="w-4 h-4 text-blue-600" />
                                            </div>
                                            <div>
                                                <p className="text-xs text-slate-500 font-semibold uppercase">Location</p>
                                                <p className="font-mono text-sm">{selectedSession.latitude?.toFixed(6)}, {selectedSession.longitude?.toFixed(6)}</p>
                                            </div>
                                        </div>
                                        <div className="flex items-center p-3 bg-slate-50 rounded-xl border border-slate-100">
                                            <div className="bg-orange-100 p-2 rounded-lg mr-3">
                                                <Clock className="w-4 h-4 text-orange-600" />
                                            </div>
                                            <div>
                                                <p className="text-xs text-slate-500 font-semibold uppercase">Last Updated</p>
                                                <p className="font-mono text-sm">{new Date(selectedSession.updatedAt).toLocaleString()}</p>
                                            </div>
                                        </div>
                                    </div>

                                    <div className="mt-6 pt-4 border-t border-slate-100">
                                        <a
                                            href={`tel:${selectedSession.phoneNumber}`}
                                            className="flex items-center justify-center w-full py-3 bg-slate-900 text-white rounded-xl hover:bg-slate-800 transition-all font-semibold"
                                        >
                                            <Phone className="w-4 h-4 mr-2" /> Call User
                                        </a>
                                    </div>
                                </div>
                            </div>
                        </div>

                        <div className="lg:col-span-2 bg-white rounded-2xl shadow-lg border border-slate-100 overflow-hidden relative min-h-[60vh] lg:min-h-0">
                            <MapContainer
                                center={[selectedSession.latitude, selectedSession.longitude]}
                                zoom={15}
                                scrollWheelZoom={true}
                                className="h-full w-full"
                                style={{ minHeight: '60vh' }}
                            >
                                <TileLayer
                                    attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
                                    url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                                />
                                <Marker position={[selectedSession.latitude, selectedSession.longitude]}>
                                    <Popup>
                                        {selectedSession.phoneNumber}<br />
                                        {selectedSession.latitude?.toFixed(6)}, {selectedSession.longitude?.toFixed(6)}
                                    </Popup>
                                </Marker>
                                <RecenterMap lat={selectedSession.latitude} lng={selectedSession.longitude} />
                            </MapContainer>
                            <div className="absolute top-0 left-0 right-0 h-20 bg-gradient-to-b from-black/10 to-transparent pointer-events-none z-[400]"></div>
                        </div>
                    </div>
                </main>
            </div>
        );
    }

    // Main admin list view
    return (
        <div className="min-h-screen bg-slate-50">
            {/* Header */}
            <header className="bg-white shadow-sm border-b border-slate-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-2">
                        <div className="bg-slate-900 p-2 rounded-lg">
                            <AlertTriangle className="w-6 h-6 text-white" />
                        </div>
                        <h1 className="text-xl font-bold text-slate-900">Suraksha+ Admin</h1>
                    </div>
                    <button
                        onClick={handleLogout}
                        className="flex items-center gap-2 text-slate-500 hover:text-slate-900 transition-colors text-sm font-medium"
                    >
                        <LogOut className="w-4 h-4" /> Logout
                    </button>
                </div>
            </header>

            <main className="max-w-7xl mx-auto px-4 py-6">
                {/* Stats */}
                <div className="grid grid-cols-3 gap-4 mb-6">
                    <div className="bg-white rounded-xl p-4 shadow-sm border border-slate-100">
                        <p className="text-xs text-slate-500 font-semibold uppercase mb-1">Total</p>
                        <p className="text-2xl font-bold text-slate-900">{sessions.length}</p>
                    </div>
                    <div className="bg-white rounded-xl p-4 shadow-sm border border-red-100">
                        <p className="text-xs text-red-500 font-semibold uppercase mb-1">Active</p>
                        <p className="text-2xl font-bold text-red-600">{activeSessions.length}</p>
                    </div>
                    <div className="bg-white rounded-xl p-4 shadow-sm border border-green-100">
                        <p className="text-xs text-green-500 font-semibold uppercase mb-1">Ended</p>
                        <p className="text-2xl font-bold text-green-600">{endedSessions.length}</p>
                    </div>
                </div>

                {/* Filter Tabs */}
                <div className="flex gap-2 mb-6">
                    {['all', 'active', 'ended'].map(f => (
                        <button
                            key={f}
                            onClick={() => setFilter(f)}
                            className={`px-4 py-2 rounded-lg text-sm font-semibold transition-all capitalize ${filter === f
                                ? 'bg-slate-900 text-white'
                                : 'bg-white text-slate-600 hover:bg-slate-100 border border-slate-200'
                                }`}
                        >
                            {f} {f === 'active' ? `(${activeSessions.length})` : f === 'ended' ? `(${endedSessions.length})` : `(${sessions.length})`}
                        </button>
                    ))}
                </div>

                {/* Session List */}
                {loading ? (
                    <div className="flex justify-center py-20">
                        <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-slate-900"></div>
                    </div>
                ) : filteredSessions.length === 0 ? (
                    <div className="text-center py-20 text-slate-400">
                        <Activity className="w-12 h-12 mx-auto mb-3 opacity-50" />
                        <p className="text-lg font-medium">No {filter !== 'all' ? filter : ''} sessions found</p>
                    </div>
                ) : (
                    <div className="grid md:grid-cols-2 lg:grid-cols-3 gap-4">
                        {filteredSessions.map(session => (
                            <div
                                key={session.id}
                                onClick={() => setSelectedSession(session)}
                                className="bg-white rounded-2xl p-5 shadow-sm hover:shadow-xl border border-slate-100 transition-all cursor-pointer group relative overflow-hidden"
                            >
                                <div className={`absolute top-0 left-0 w-1 h-full ${session.isActive ? 'bg-red-500' : 'bg-green-500'} group-hover:w-2 transition-all`}></div>

                                <div className="flex justify-between items-start mb-3">
                                    <div className="flex items-center gap-3">
                                        <div className={`w-10 h-10 rounded-full flex items-center justify-center ${session.isActive ? 'bg-red-50 text-red-500' : 'bg-green-50 text-green-500'}`}>
                                            {session.isActive ? <AlertTriangle className="w-5 h-5" /> : <ShieldCheck className="w-5 h-5" />}
                                        </div>
                                        <div>
                                            <h3 className="font-bold text-slate-900">{session.phoneNumber}</h3>
                                            <span className={`text-xs font-medium px-2 py-0.5 rounded-full ${session.isActive
                                                ? 'bg-red-100 text-red-700'
                                                : 'bg-green-100 text-green-700'
                                                }`}>
                                                {session.isActive ? 'SOS ACTIVE' : 'ENDED'}
                                            </span>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        {session.isActive && (
                                            <span className="animate-pulse w-3 h-3 bg-red-500 rounded-full shadow-[0_0_10px_rgba(255,59,48,0.5)]"></span>
                                        )}
                                        <button
                                            onClick={(e) => deleteSession(e, session.id)}
                                            className="p-1.5 rounded-lg text-slate-300 hover:text-red-500 hover:bg-red-50 transition-all opacity-0 group-hover:opacity-100"
                                            title="Delete session"
                                        >
                                            <Trash2 className="w-4 h-4" />
                                        </button>
                                    </div>
                                </div>

                                <div className="space-y-1.5 mb-4">
                                    <div className="flex items-center text-sm text-slate-600">
                                        <MapPin className="w-4 h-4 mr-2 text-slate-400" />
                                        {session.latitude?.toFixed(4)}, {session.longitude?.toFixed(4)}
                                    </div>
                                    <div className="flex items-center text-sm text-slate-600">
                                        <Clock className="w-4 h-4 mr-2 text-slate-400" />
                                        {new Date(session.updatedAt).toLocaleString()}
                                    </div>
                                </div>

                                <button className={`w-full py-2 font-semibold rounded-lg text-sm transition-colors ${session.isActive
                                    ? 'bg-slate-50 text-slate-700 group-hover:bg-red-500 group-hover:text-white'
                                    : 'bg-slate-50 text-slate-700 group-hover:bg-green-500 group-hover:text-white'
                                    }`}>
                                    View Details
                                </button>
                            </div>
                        ))}
                    </div>
                )}
            </main>
        </div>
    );
}

// ═══════════════════════════════════════════════════════════════════
// APP — Routes based on URL
// ═══════════════════════════════════════════════════════════════════

function App() {
    const [isAdmin, setIsAdmin] = useState(sessionStorage.getItem('admin_auth') === 'true');

    const pathname = window.location.pathname;
    const urlParams = new URLSearchParams(window.location.search);
    const sessionId = urlParams.get('session');

    // ?session=ID → tracking page (any path)
    if (sessionId) {
        return <TrackingPage sessionId={sessionId} />;
    }

    // /admin → admin dashboard (password protected)
    if (pathname === '/admin' || pathname === '/admin/') {
        if (!isAdmin) {
            return <AdminLogin onLogin={() => setIsAdmin(true)} />;
        }
        return <AdminDashboard />;
    }

    // Default: show a simple message
    return (
        <div className="min-h-screen bg-slate-50 flex items-center justify-center">
            <div className="text-center">
                <AlertTriangle className="w-16 h-16 text-slate-300 mx-auto mb-4" />
                <h2 className="text-xl font-bold text-slate-700">Invalid Tracking Link</h2>
                <p className="text-slate-400 mt-2">Please use the link provided in your SMS.</p>
            </div>
        </div>
    );
}

export default App;
