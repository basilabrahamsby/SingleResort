import React, { useState, useEffect, useMemo } from 'react';
import { X, Calendar, Clock, DollarSign, User, Phone, Mail, Briefcase, MapPin, Users, TrendingUp, Award, CheckSquare, Trash2, Plus } from 'lucide-react';
import api from '../services/api';
import { formatCurrency } from '../utils/currency';
import { formatDateIST, formatDateTimeIST } from '../utils/dateUtils';
import { motion, AnimatePresence } from 'framer-motion';

const EmployeeProfileModal = ({ employeeId, onClose }) => {
    const [activeTab, setActiveTab] = useState('attendance');
    const [employee, setEmployee] = useState(null);
    const [workLogs, setWorkLogs] = useState([]);
    const [leaves, setLeaves] = useState([]);
    const [loading, setLoading] = useState(true);
    const [newTask, setNewTask] = useState('');
    const [isUpdating, setIsUpdating] = useState(false);

    useEffect(() => {
        if (employeeId) {
            setLoading(true);
            Promise.all([
                api.get(`/employees/${employeeId}`).catch(() => ({ data: null })),
                api.get(`/attendance/work-logs/${employeeId}`).catch(() => ({ data: [] })),
                api.get(`/employees/leave/${employeeId}`).catch(() => ({ data: [] })),
            ]).then(([empRes, workRes, leaveRes]) => {
                setEmployee(empRes.data);
                setWorkLogs(workRes.data || []);
                setLeaves(leaveRes.data || []);
            }).finally(() => setLoading(false));
        }
    }, [employeeId]);

    const stats = useMemo(() => {
        const totalDays = workLogs.length;
        const totalHours = workLogs.reduce((sum, log) => sum + (log.duration_hours || 0), 0);
        const usedLeaves = leaves.filter(l => l.status === 'approved').length;
        const availableLeaves = 12 - usedLeaves;

        return { totalDays, totalHours, usedLeaves, availableLeaves };
    }, [workLogs, leaves]);

    const handleAddTask = async () => {
        if (!newTask.trim() || !employee) return;

        setIsUpdating(true);
        try {
            let currentTasks = [];
            try {
                currentTasks = employee.daily_tasks ? JSON.parse(employee.daily_tasks) : [];
                if (!Array.isArray(currentTasks)) currentTasks = employee.daily_tasks ? [employee.daily_tasks] : [];
            } catch {
                currentTasks = employee.daily_tasks ? [employee.daily_tasks] : [];
            }

            const updatedTasks = [...currentTasks, newTask.trim()];
            const formData = new FormData();
            formData.append('daily_tasks', JSON.stringify(updatedTasks));

            // Use the correct API endpoint
            const response = await api.put(`/employees/${employee.id}`, formData);
            setEmployee(response.data);
            setNewTask('');
        } catch (error) {
            console.error("Failed to add task:", error);
            alert("Failed to add task.");
        } finally {
            setIsUpdating(false);
        }
    };

    const handleDeleteTask = async (taskToDelete) => {
        if (!window.confirm(`Delete task: "${taskToDelete}"?`) || !employee) return;

        setIsUpdating(true);
        try {
            let currentTasks = [];
            try {
                currentTasks = employee.daily_tasks ? JSON.parse(employee.daily_tasks) : [];
                if (!Array.isArray(currentTasks)) currentTasks = employee.daily_tasks ? [employee.daily_tasks] : [];
            } catch {
                currentTasks = employee.daily_tasks ? [employee.daily_tasks] : [];
            }

            const updatedTasks = currentTasks.filter(t => t !== taskToDelete);
            const formData = new FormData();
            formData.append('daily_tasks', JSON.stringify(updatedTasks));

            const response = await api.put(`/employees/${employee.id}`, formData);
            setEmployee(response.data);
        } catch (error) {
            console.error("Failed to delete task:", error);
            alert("Failed to delete task.");
        } finally {
            setIsUpdating(false);
        }
    };

    if (loading) {
        return (
            <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
                <div className="bg-white rounded-2xl p-8">
                    <p className="text-gray-600">Loading employee profile...</p>
                </div>
            </div>
        );
    }

    if (!employee) {
        return (
            <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50">
                <div className="bg-white rounded-2xl p-8">
                    <p className="text-red-600">Employee not found</p>
                    <button onClick={onClose} className="mt-4 px-4 py-2 bg-gray-200 rounded-lg">Close</button>
                </div>
            </div>
        );
    }

    return (
        <div className="fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50 p-4">
            <motion.div
                initial={{ opacity: 0, scale: 0.9 }}
                animate={{ opacity: 1, scale: 1 }}
                exit={{ opacity: 0, scale: 0.9 }}
                className="bg-white rounded-2xl shadow-2xl max-w-6xl w-full max-h-[90vh] overflow-hidden flex flex-col"
            >
                {/* Header */}
                <div className="bg-gradient-to-r from-indigo-600 to-purple-600 p-6 text-white">
                    <div className="flex items-center justify-between">
                        <div className="flex items-center space-x-4">
                            <div className="w-16 h-16 bg-white bg-opacity-20 rounded-full flex items-center justify-center">
                                <User size={32} />
                            </div>
                            <div>
                                <h2 className="text-2xl font-bold">{employee.name}</h2>
                                <p className="text-indigo-100">ID: {employee.id} • {employee.role}</p>
                            </div>
                        </div>
                        <button
                            onClick={onClose}
                            className="p-2 hover:bg-white hover:bg-opacity-20 rounded-full transition"
                        >
                            <X size={24} />
                        </button>
                    </div>

                    {/* Quick Stats */}
                    <div className="grid grid-cols-4 gap-4 mt-6">
                        <div className="bg-white bg-opacity-20 rounded-lg p-3">
                            <div className="flex items-center space-x-2 mb-1">
                                <Calendar size={16} />
                                <span className="text-xs opacity-90">Days Worked</span>
                            </div>
                            <p className="text-2xl font-bold">{stats.totalDays}</p>
                        </div>
                        <div className="bg-white bg-opacity-20 rounded-lg p-3">
                            <div className="flex items-center space-x-2 mb-1">
                                <Clock size={16} />
                                <span className="text-xs opacity-90">Total Hours</span>
                            </div>
                            <p className="text-2xl font-bold">{stats.totalHours.toFixed(1)}h</p>
                        </div>
                        <div className="bg-white bg-opacity-20 rounded-lg p-3">
                            <div className="flex items-center space-x-2 mb-1">
                                <Award size={16} />
                                <span className="text-xs opacity-90">Leaves Used</span>
                            </div>
                            <p className="text-2xl font-bold">{stats.usedLeaves}</p>
                        </div>
                        <div className="bg-white bg-opacity-20 rounded-lg p-3">
                            <div className="flex items-center space-x-2 mb-1">
                                <DollarSign size={16} />
                                <span className="text-xs opacity-90">Salary</span>
                            </div>
                            <p className="text-2xl font-bold">{formatCurrency(employee.salary || 0)}</p>
                        </div>
                    </div>
                </div>

                {/* Tabs */}
                <div className="border-b border-gray-200 bg-gray-50">
                    <div className="flex space-x-8 px-6">
                        {[
                            { id: 'attendance', label: 'Attendance', icon: Clock },
                            { id: 'leaves', label: 'Leaves', icon: Calendar },
                            { id: 'tasks', label: 'Tasks', icon: CheckSquare },
                            { id: 'payments', label: 'Payments', icon: DollarSign },
                            { id: 'details', label: 'Details', icon: User },
                        ].map(tab => (
                            <button
                                key={tab.id}
                                onClick={() => setActiveTab(tab.id)}
                                className={`flex items-center space-x-2 py-4 px-2 border-b-2 transition ${activeTab === tab.id
                                    ? 'border-indigo-600 text-indigo-600'
                                    : 'border-transparent text-gray-500 hover:text-gray-700'
                                    }`}
                            >
                                <tab.icon size={18} />
                                <span className="font-medium">{tab.label}</span>
                            </button>
                        ))}
                    </div>
                </div>

                {/* Tab Content */}
                <div className="flex-1 overflow-y-auto p-6">
                    <AnimatePresence mode="wait">
                        {activeTab === 'attendance' && (
                            <motion.div
                                key="attendance"
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -20 }}
                                className="space-y-4"
                            >
                                <h3 className="text-lg font-semibold text-gray-800 mb-4">Attendance History</h3>
                                {workLogs.length === 0 ? (
                                    <div className="text-center py-12 bg-gray-50 rounded-lg">
                                        <Clock size={48} className="mx-auto text-gray-300 mb-3" />
                                        <p className="text-gray-500">No attendance records found</p>
                                    </div>
                                ) : (
                                    <div className="space-y-3">
                                        {workLogs.map((log, index) => {
                                            const duration = log.duration_hours || 0;
                                            const isActive = !log.check_out_time;

                                            return (
                                                <div key={index} className="bg-white border border-gray-200 rounded-lg p-4 hover:shadow-md transition">
                                                    <div className="flex items-center justify-between">
                                                        <div className="flex items-center space-x-4">
                                                            <div className={`w-12 h-12 rounded-full flex items-center justify-center ${isActive ? 'bg-green-100' : 'bg-gray-100'
                                                                }`}>
                                                                <Clock size={20} className={isActive ? 'text-green-600' : 'text-gray-600'} />
                                                            </div>
                                                            <div>
                                                                <p className="font-semibold text-gray-800">
                                                                    {formatDateIST(log.date, { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' })}
                                                                </p>
                                                                <div className="flex items-center space-x-4 text-sm text-gray-600 mt-1">
                                                                    <span className="flex items-center">
                                                                        <span className="text-green-600 mr-1">In:</span>
                                                                        {log.check_in_time || 'N/A'}
                                                                    </span>
                                                                    <span className="flex items-center">
                                                                        <span className="text-red-600 mr-1">Out:</span>
                                                                        {log.check_out_time || 'Still working'}
                                                                    </span>
                                                                </div>
                                                            </div>
                                                        </div>
                                                        <div className="text-right">
                                                            {isActive ? (
                                                                <span className="inline-block px-3 py-1 bg-green-100 text-green-700 rounded-full text-sm font-medium">
                                                                    Active
                                                                </span>
                                                            ) : (
                                                                <div>
                                                                    <p className="text-2xl font-bold text-indigo-600">{duration.toFixed(1)}h</p>
                                                                    <p className="text-xs text-gray-500">Duration</p>
                                                                </div>
                                                            )}
                                                        </div>
                                                    </div>
                                                </div>
                                            );
                                        })}
                                    </div>
                                )}
                            </motion.div>
                        )}

                        {activeTab === 'leaves' && (
                            <motion.div
                                key="leaves"
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -20 }}
                                className="space-y-4"
                            >
                                <div className="flex items-center justify-between mb-4">
                                    <h3 className="text-lg font-semibold text-gray-800">Leave History</h3>
                                    <div className="flex items-center space-x-4">
                                        <div className="text-center px-4 py-2 bg-green-50 rounded-lg">
                                            <p className="text-xs text-green-600">Available</p>
                                            <p className="text-xl font-bold text-green-700">{stats.availableLeaves}</p>
                                        </div>
                                        <div className="text-center px-4 py-2 bg-red-50 rounded-lg">
                                            <p className="text-xs text-red-600">Used</p>
                                            <p className="text-xl font-bold text-red-700">{stats.usedLeaves}</p>
                                        </div>
                                    </div>
                                </div>

                                {leaves.length === 0 ? (
                                    <div className="text-center py-12 bg-gray-50 rounded-lg">
                                        <Calendar size={48} className="mx-auto text-gray-300 mb-3" />
                                        <p className="text-gray-500">No leave records found</p>
                                    </div>
                                ) : (
                                    <div className="space-y-3">
                                        {leaves.map((leave, index) => {
                                            const fromDate = new Date(leave.from_date);
                                            const toDate = new Date(leave.to_date);
                                            const days = Math.ceil((toDate - fromDate) / (1000 * 60 * 60 * 24)) + 1;

                                            const statusColors = {
                                                approved: 'bg-green-100 text-green-700 border-green-300',
                                                pending: 'bg-yellow-100 text-yellow-700 border-yellow-300',
                                                rejected: 'bg-red-100 text-red-700 border-red-300',
                                            };

                                            return (
                                                <div key={index} className="bg-white border border-gray-200 rounded-lg p-4">
                                                    <div className="flex items-start justify-between">
                                                        <div className="flex-1">
                                                            <div className="flex items-center space-x-3 mb-2">
                                                                <h4 className="font-semibold text-gray-800">{leave.type || 'Leave'}</h4>
                                                                <span className={`px-3 py-1 rounded-full text-xs font-medium border ${statusColors[leave.status] || statusColors.pending}`}>
                                                                    {leave.status?.charAt(0).toUpperCase() + leave.status?.slice(1)}
                                                                </span>
                                                            </div>
                                                            <div className="flex items-center space-x-4 text-sm text-gray-600 mb-2">
                                                                <span className="flex items-center">
                                                                    <Calendar size={14} className="mr-1" />
                                                                    {formatDateIST(leave.from_date)} to {formatDateIST(leave.to_date)}
                                                                </span>
                                                                <span className="font-medium">({days} {days > 1 ? 'days' : 'day'})</span>
                                                            </div>
                                                            <p className="text-sm text-gray-600">{leave.reason || 'No reason provided'}</p>
                                                        </div>
                                                    </div>
                                                </div>
                                            );
                                        })}
                                    </div>
                                )}
                            </motion.div>
                        )}

                        {activeTab === 'payments' && (
                            <motion.div
                                key="payments"
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -20 }}
                                className="space-y-4"
                            >
                                <h3 className="text-lg font-semibold text-gray-800 mb-4">Payment History</h3>

                                {/* Current Month Salary */}
                                <div className="bg-gradient-to-r from-green-500 to-emerald-600 text-white rounded-xl p-6 mb-6">
                                    <div className="flex items-center space-x-3 mb-4">
                                        <DollarSign size={28} />
                                        <h4 className="text-lg font-semibold">Current Month Salary</h4>
                                    </div>
                                    <p className="text-sm opacity-90 mb-2">Estimated</p>
                                    <p className="text-4xl font-bold">{formatCurrency(employee.salary || 0)}</p>
                                </div>

                                {/* Payment History - Sample Data */}
                                <div className="text-center py-12 bg-gray-50 rounded-lg border-2 border-dashed border-gray-300">
                                    <DollarSign size={48} className="mx-auto text-gray-300 mb-3" />
                                    <p className="text-gray-600 font-medium">Payment history coming soon</p>
                                    <p className="text-sm text-gray-500 mt-2">Detailed salary slips and payment records will be available here</p>
                                </div>
                            </motion.div>
                        )}

                        {activeTab === 'tasks' && (
                            <motion.div
                                key="tasks"
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -20 }}
                                className="space-y-4"
                            >
                                <div className="flex items-center justify-between mb-4">
                                    <h3 className="text-lg font-semibold text-gray-800">Daily Operations</h3>
                                    <span className="text-xs text-gray-500 font-medium uppercase tracking-widest">Fixed Shift Tasks</span>
                                </div>

                                {/* Add Task Input */}
                                <div className="flex gap-2 mb-6 p-4 bg-gray-50 rounded-xl border border-gray-100">
                                    <input
                                        type="text"
                                        value={newTask}
                                        onChange={(e) => setNewTask(e.target.value)}
                                        onKeyDown={(e) => e.key === 'Enter' && handleAddTask()}
                                        placeholder="Define a new daily task..."
                                        className="flex-1 px-4 py-2 border border-gray-200 rounded-lg focus:ring-2 focus:ring-indigo-500 outline-none text-sm font-medium"
                                        disabled={isUpdating}
                                    />
                                    <button
                                        onClick={handleAddTask}
                                        disabled={isUpdating || !newTask.trim()}
                                        className="px-6 py-2 bg-indigo-600 text-white rounded-lg text-sm font-bold hover:bg-indigo-700 transition disabled:opacity-50 flex items-center gap-2"
                                    >
                                        <Plus size={16} />
                                        Add Task
                                    </button>
                                </div>

                                {(() => {
                                    let tasks = [];
                                    try {
                                        tasks = employee.daily_tasks ? JSON.parse(employee.daily_tasks) : [];
                                        if (!Array.isArray(tasks)) tasks = employee.daily_tasks ? [employee.daily_tasks] : [];
                                    } catch {
                                        tasks = employee.daily_tasks ? [employee.daily_tasks] : [];
                                    }

                                    if (tasks.length === 0) {
                                        return (
                                            <div className="text-center py-12 bg-gray-50 rounded-lg border-2 border-dashed border-gray-200">
                                                <CheckSquare size={48} className="mx-auto text-gray-300 mb-3" />
                                                <p className="text-gray-500 font-medium">No daily tasks defined for this employee.</p>
                                                <p className="text-xs text-gray-400 mt-1">Add tasks above to ensure shift integrity.</p>
                                            </div>
                                        );
                                    }

                                    return (
                                        <div className="space-y-2">
                                            {tasks.map((task, idx) => (
                                                <div key={idx} className="flex items-center justify-between p-4 bg-white border border-gray-200 rounded-xl hover:border-indigo-200 hover:shadow-sm transition-all group">
                                                    <div className="flex items-center gap-4">
                                                        <div className="w-8 h-8 rounded-lg bg-indigo-50 flex items-center justify-center text-indigo-600">
                                                            <CheckSquare size={16} />
                                                        </div>
                                                        <span className="text-gray-800 font-semibold">{task}</span>
                                                    </div>
                                                    <button
                                                        onClick={() => handleDeleteTask(task)}
                                                        className="p-2 text-gray-300 hover:text-red-600 hover:bg-red-50 rounded-lg transition-all opacity-0 group-hover:opacity-100"
                                                        title="Remove Task"
                                                    >
                                                        <Trash2 size={16} />
                                                    </button>
                                                </div>
                                            ))}
                                        </div>
                                    );
                                })()}
                            </motion.div>
                        )}

                        {activeTab === 'details' && (
                            <motion.div
                                key="details"
                                initial={{ opacity: 0, y: 20 }}
                                animate={{ opacity: 1, y: 0 }}
                                exit={{ opacity: 0, y: -20 }}
                                className="space-y-6"
                            >
                                <h3 className="text-lg font-semibold text-gray-800 mb-4">Employee Details</h3>

                                {/* Personal Information */}
                                <div className="bg-white border border-gray-200 rounded-lg p-5">
                                    <div className="flex items-center space-x-2 mb-4">
                                        <User size={20} className="text-indigo-600" />
                                        <h4 className="font-semibold text-gray-800">Personal Information</h4>
                                    </div>
                                    <div className="grid grid-cols-2 gap-4">
                                        <div>
                                            <p className="text-sm text-gray-500">Name</p>
                                            <p className="font-medium text-gray-800">{employee.name}</p>
                                        </div>
                                        <div>
                                            <p className="text-sm text-gray-500">Employee ID</p>
                                            <p className="font-medium text-gray-800">{employee.id}</p>
                                        </div>
                                        <div>
                                            <p className="text-sm text-gray-500">Department</p>
                                            <p className="font-medium text-gray-800">{employee.role || 'N/A'}</p>
                                        </div>
                                        <div>
                                            <p className="text-sm text-gray-500">Join Date</p>
                                            <p className="font-medium text-gray-800">
                                                {employee.join_date ? formatDateIST(employee.join_date) : 'N/A'}
                                            </p>
                                        </div>
                                    </div>
                                </div>

                                {/* Contact Information */}
                                <div className="bg-white border border-gray-200 rounded-lg p-5">
                                    <div className="flex items-center space-x-2 mb-4">
                                        <Phone size={20} className="text-indigo-600" />
                                        <h4 className="font-semibold text-gray-800">Contact Information</h4>
                                    </div>
                                    <div className="grid grid-cols-2 gap-4">
                                        <div>
                                            <p className="text-sm text-gray-500">Email</p>
                                            <p className="font-medium text-gray-800">{employee.user?.email || 'N/A'}</p>
                                        </div>
                                        <div>
                                            <p className="text-sm text-gray-500">Phone</p>
                                            <p className="font-medium text-gray-800">{employee.user?.phone || 'N/A'}</p>
                                        </div>
                                    </div>
                                </div>

                                {/* Work Information */}
                                <div className="bg-white border border-gray-200 rounded-lg p-5">
                                    <div className="flex items-center space-x-2 mb-4">
                                        <Briefcase size={20} className="text-indigo-600" />
                                        <h4 className="font-semibold text-gray-800">Work Information</h4>
                                    </div>
                                    <div className="grid grid-cols-2 gap-4">
                                        <div>
                                            <p className="text-sm text-gray-500">Position</p>
                                            <p className="font-medium text-gray-800">{employee.role || 'Staff'}</p>
                                        </div>
                                        <div>
                                            <p className="text-sm text-gray-500">Salary</p>
                                            <p className="font-medium text-gray-800">{formatCurrency(employee.salary || 0)}</p>
                                        </div>
                                        <div>
                                            <p className="text-sm text-gray-500">Status</p>
                                            <p className="font-medium text-gray-800">
                                                <span className={`px-2 py-1 rounded-full text-xs ${employee.user?.is_active ? 'bg-green-100 text-green-700' : 'bg-red-100 text-red-700'
                                                    }`}>
                                                    {employee.user?.is_active ? 'Active' : 'Inactive'}
                                                </span>
                                            </p>
                                        </div>
                                    </div>
                                </div>
                            </motion.div>
                        )}
                    </AnimatePresence>
                </div>
            </motion.div>
        </div>
    );
};

export default EmployeeProfileModal;
