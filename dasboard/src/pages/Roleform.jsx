// src/pages/RoleForm.jsx
import React, { useState, useEffect } from "react";
import API from "../services/api";
import DashboardLayout from "../layout/DashboardLayout";
import { Trash2, CheckCircle, XCircle, Edit, ChevronDown, ChevronRight } from "lucide-react";

const availablePermissions = [
  { label: "Dashboard", value: "/dashboard" },
  {
    label: "Account",
    value: "/account",
    tabs: [
      { label: "Reports Dashboard", value: "/account/reports" },
      { label: "Chart of Accounts", value: "/account/chart-of-accounts" },
      { label: "Journal Entries", value: "/account/journal-entries" },
      { label: "Trial Balance", value: "/account/trial-balance" },
      { label: "Auto Report", value: "/account/auto-report" },
      { label: "Comprehensive Report", value: "/account/comprehensive-report" },
      { label: "GST Reports", value: "/account/gst-reports" }
    ]
  },
  { label: "Bookings", value: "/bookings" },
  { label: "Rooms", value: "/rooms" },
  {
    label: "Services",
    value: "/services",
    tabs: [
      { label: "Dashboard", value: "/services/dashboard" },
      { label: "Create Service", value: "/services/create" },
      { label: "Assign Service", value: "/services/assign" },
      { label: "Assigned Services", value: "/services/assigned" },
      { label: "Service Requests", value: "/services/requests" },
      { label: "Report", value: "/services/report" }
    ]
  },
  {
    label: "Food Orders",
    value: "/food-orders",
    tabs: [
      { label: "Dashboard", value: "/food-orders/dashboard" },
      { label: "Orders", value: "/food-orders/orders" },
      { label: "Requests", value: "/food-orders/requests" },
      { label: "Management", value: "/food-orders/management" }
    ]
  },
  {
    label: "Employee Management",
    value: "/employee-management",
    tabs: [
      { label: "Overview", value: "/employee-management/overview" },
      { label: "Directory", value: "/employee-management/directory" },
      { label: "Attendance", value: "/employee-management/attendance" },
      { label: "Leave", value: "/employee-management/leave" },
      { label: "Reports", value: "/employee-management/reports" },
      { label: "Status", value: "/employee-management/status" },
      { label: "Activity", value: "/employee-management/activity" }
    ]
  },
  { label: "Role", value: "/roles" },
  { label: "Expenses", value: "/expenses" },
  {
    label: "Food Management",
    value: "/food-categories",
    tabs: [
      { label: "Categories", value: "/food-categories" },
      { label: "Food Items", value: "/food-items" }
    ]
  },
  {
    label: "Billing",
    value: "/billing",
    tabs: [
      { label: "Checkout", value: "/billing/checkout" },
      { label: "History", value: "/billing/history" }
    ]
  },
  {
    label: "WEB Management",
    value: "/Userfrontend_data",
    tabs: [
      { label: "Banners", value: "/Userfrontend_data/banners" },
      { label: "Gallery", value: "/Userfrontend_data/gallery" },
      { label: "Reviews", value: "/Userfrontend_data/reviews" },
      { label: "Resort Info", value: "/Userfrontend_data/resortInfo" },
      { label: "Experiences", value: "/Userfrontend_data/signatureExperiences" },
      { label: "Weddings", value: "/Userfrontend_data/planWeddings" },
      { label: "Attractions", value: "/Userfrontend_data/nearbyAttractions" },
      { label: "Attraction Banners", value: "/Userfrontend_data/nearbyAttractionBanners" }
    ]
  },
  { label: "Packages", value: "/package" },
  { label: "Reports", value: "/report" },
  { label: "GuestProfiles", value: "/guestprofiles" },
  {
    label: "Inventory",
    value: "/inventory",
    tabs: [
      { label: "Items", value: "/inventory/items" },
      { label: "Categories", value: "/inventory/categories" },
      { label: "Vendors", value: "/inventory/vendors" },
      { label: "Purchases", value: "/inventory/purchases" },
      { label: "Transactions", value: "/inventory/transactions" },
      { label: "Requisitions", value: "/inventory/requisitions" },
      { label: "Issues", value: "/inventory/issues" },
      { label: "Waste", value: "/inventory/waste" },
      { label: "Locations", value: "/inventory/locations" },
      { label: "Assets", value: "/inventory/assets" },
      { label: "Location Stock", value: "/inventory/location-stock" },
      { label: "Recipes", value: "/inventory/recipe" }
    ]
  },
  {
    label: "Mobile App Access",
    value: "/mobile",
    tabs: [
      { label: "Owner Mobile App", value: "/mobile/owner" },
      { label: "Manager Mobile App", value: "/mobile/manager" },
      { label: "Kitchen/F&B Module", value: "/mobile/kitchen" },
      { label: "Housekeeping Module", value: "/mobile/housekeeping" },
      { label: "Maintenance/Technical", value: "/mobile/maintenance" },
      { label: "Waiter/Order App", value: "/mobile/waiter" },
      { label: "Staff Portal Mobile", value: "/mobile/employee" }
    ]

  },
  {
    label: "Settings",
    value: "/settings",
    tabs: [
      { label: "System Settings", value: "/settings/system" },
      { label: "Legal Documents", value: "/settings/legal" }
    ]
  }
];

// Define roles that cannot be deleted from the UI
const PROTECTED_ROLES = ['admin'];

const RoleForm = () => {
  const [form, setForm] = useState({ name: "", permissions: [] });
  const [roles, setRoles] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [editRoleId, setEditRoleId] = useState(null);
  const [showConfirm, setShowConfirm] = useState(false);
  const [roleToDelete, setRoleToDelete] = useState(null);
  const [expandedSections, setExpandedSections] = useState({});

  const fetchRoles = async () => {
    try {
      const response = await API.get("/roles");
      setRoles(response.data);
    } catch (err) {
      console.error("Failed to fetch roles", err);
    }
  };

  useEffect(() => {
    fetchRoles();
  }, []);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setForm((prev) => ({ ...prev, [name]: value.trimStart() }));
  };

  const handlePermissionChange = (permissionValue) => {
    setForm((prev) => {
      const newPermissions = prev.permissions.includes(permissionValue)
        ? prev.permissions.filter((p) => p !== permissionValue)
        : [...prev.permissions, permissionValue];
      return { ...prev, permissions: newPermissions };
    });
  };

  const toggleSection = (value) => {
    setExpandedSections(prev => ({
      ...prev,
      [value]: !prev[value]
    }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError("");
    setSuccess("");
    try {
      const payload = {
        ...form,
        permissions: JSON.stringify(form.permissions),
      };
      if (editRoleId) {
        await API.put(`/roles/${editRoleId}`, payload);
        setSuccess("Role updated successfully!");
      } else {
        await API.post("/roles", payload);
        setSuccess("Role created successfully!");
      }
      setForm({ name: "", permissions: [] });
      setEditRoleId(null);
      await fetchRoles();
    } catch (err) {
      if (editRoleId && err.response && err.response.status === 404) {
        setError("Failed to update role. It may have been deleted by another user.");
        setEditRoleId(null);
        setForm({ name: "", permissions: [] });
        await fetchRoles();
      } else {
        const errorMsg = err.response?.data?.detail || err.message || (editRoleId ? "Failed to update role" : "Failed to create role");
        setError(errorMsg);
      }
    }
    setLoading(false);
  };

  const handleEditClick = (role) => {
    setEditRoleId(role.id);
    setForm({
      name: role.name,
      permissions: role.permissions || [],
    });
    setSuccess("");
    setError("");
    window.scrollTo({ top: 0, behavior: "smooth" });
  };

  const handleCancelEdit = () => {
    setEditRoleId(null);
    setForm({ name: "", permissions: [] });
    setSuccess("");
    setError("");
  };

  const handleDeleteClick = (role) => {
    setRoleToDelete(role);
    setShowConfirm(true);
  };

  const handleConfirmDelete = async () => {
    if (!roleToDelete) return;
    setLoading(true);
    setError("");
    setSuccess("");
    setShowConfirm(false);
    try {
      await API.delete(`/roles/${roleToDelete.id}`);
      await fetchRoles();
      setSuccess("Role deleted successfully!");
    } catch (err) {
      if (err.response && err.response.status === 404) {
        setError("Failed to delete role. It may have already been deleted.");
      } else {
        setError("Failed to delete role. Please try again.");
      }
    } finally {
      setLoading(false);
      setRoleToDelete(null);
    }
  };

  const handleCancelDelete = () => {
    setRoleToDelete(null);
    setShowConfirm(false);
  };

  return (
    <DashboardLayout>
      <div className="max-w-6xl mx-auto p-8 bg-gray-50 rounded-2xl shadow-lg space-y-10">
        <h2 className="text-4xl font-extrabold text-blue-900 text-center tracking-tight">Role Management</h2>

        {/* Alerts */}
        {success && (
          <div className="flex items-center gap-2 p-4 text-sm font-medium text-green-700 bg-green-100 rounded-lg">
            <CheckCircle size={20} />
            {success}
          </div>
        )}
        {error && (
          <div className="flex items-center gap-2 p-4 text-sm font-medium text-red-700 bg-red-100 rounded-lg">
            <XCircle size={20} />
            {error}
          </div>
        )}

        {/* Role Creation Form */}
        <div className="bg-white p-6 rounded-xl shadow-md space-y-6">
          <h3 className="text-2xl font-semibold text-blue-800 border-b pb-4">{editRoleId ? "Edit Role" : "Create New Role"}</h3>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div>
              <label htmlFor="roleName" className="block text-sm font-semibold text-gray-700 mb-1">
                Role Name
              </label>
              <input
                id="roleName"
                type="text"
                name="name"
                value={form.name}
                onChange={handleChange}
                required
                placeholder="e.g., Administrator, Manager, Staff"
                className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-blue-500 transition-colors"
              />
            </div>

            <div>
              <label className="block text-sm font-semibold text-gray-700 mb-2">Permissions</label>
              <div className="space-y-2 p-4 border rounded-lg bg-gray-50 max-h-96 overflow-y-auto">
                {availablePermissions.map((permission) => (
                  <div key={permission.value} className="space-y-1">
                    <div className="flex items-center gap-2">
                      {permission.tabs && (
                        <button
                          type="button"
                          onClick={() => toggleSection(permission.value)}
                          className="text-gray-500 hover:text-gray-700"
                        >
                          {expandedSections[permission.value] ? <ChevronDown size={16} /> : <ChevronRight size={16} />}
                        </button>
                      )}
                      <label className="flex items-center gap-2 text-sm text-gray-800 cursor-pointer font-medium">
                        <input
                          type="checkbox"
                          checked={form.permissions.includes(permission.value)}
                          onChange={() => handlePermissionChange(permission.value)}
                          className="h-4 w-4 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                        />
                        {permission.label}
                      </label>
                    </div>

                    {/* Sub-tabs */}
                    {permission.tabs && expandedSections[permission.value] && (
                      <div className="ml-8 space-y-1 border-l-2 border-gray-200 pl-4">
                        {permission.tabs.map((tab) => (
                          <label key={tab.value} className="flex items-center gap-2 text-sm text-gray-600 cursor-pointer">
                            <input
                              type="checkbox"
                              checked={form.permissions.includes(tab.value)}
                              onChange={() => handlePermissionChange(tab.value)}
                              className="h-3.5 w-3.5 rounded border-gray-300 text-blue-600 focus:ring-blue-500"
                            />
                            {tab.label}
                          </label>
                        ))}
                      </div>
                    )}
                  </div>
                ))}
              </div>
            </div>

            <div className="flex gap-4 pt-4">
              <button
                type="submit"
                disabled={loading}
                className="flex-1 py-3 bg-blue-600 hover:bg-blue-700 text-white font-bold rounded-lg shadow-lg transition-transform transform hover:scale-105 disabled:bg-gray-400 disabled:cursor-not-allowed"
              >
                {loading ? "Saving..." : (editRoleId ? "Update Role" : "Create Role")}
              </button>
              {editRoleId && (
                <button
                  type="button"
                  onClick={handleCancelEdit}
                  className="flex-1 py-3 bg-gray-200 hover:bg-gray-300 text-gray-800 font-bold rounded-lg shadow-lg transition-transform transform hover:scale-105"
                >
                  Cancel
                </button>
              )}
            </div>
          </form>
        </div>

        {/* Existing Roles Table */}
        <div className="space-y-4 bg-white p-6 rounded-xl shadow-md">
          <h3 className="text-2xl font-semibold text-blue-800 border-b pb-4">Existing Roles</h3>
          <div className="overflow-x-auto rounded-lg border border-gray-200 shadow-sm">
            <table className="min-w-full text-sm text-left">
              <thead className="bg-gray-100 text-gray-700 uppercase tracking-wider">
                <tr>
                  <th className="px-6 py-3">#</th>
                  <th className="px-6 py-3">Role Name</th>
                  <th className="px-6 py-3 text-right">Actions</th>
                </tr>
              </thead>
              <tbody>
                {roles.length > 0 ? (
                  roles.map((role) => {
                    const isProtected = PROTECTED_ROLES.includes(role.name.toLowerCase());
                    return (
                      <tr key={role.id} className="border-t border-gray-200 hover:bg-gray-50 transition-colors group">
                        <td className="px-6 py-4 font-mono text-gray-500">{role.id}</td>
                        <td className="px-6 py-4 font-medium text-gray-900">{role.name}</td>
                        <td className="px-6 py-4 text-right">
                          <div className="flex items-center justify-end gap-4 opacity-0 group-hover:opacity-100 transition-opacity">
                            <button
                              onClick={() => handleEditClick(role)}
                              className="text-blue-600 hover:text-blue-800 transition-colors"
                              title="Edit Role"
                            >
                              <Edit size={18} />
                            </button>
                            <button
                              onClick={() => handleDeleteClick(role)}
                              className={`transition-colors ${isProtected ? 'text-gray-400 cursor-not-allowed' : 'text-red-600 hover:text-red-800'}`}
                              title={isProtected ? "This role cannot be deleted" : "Delete Role"}
                              disabled={isProtected}
                            >
                              <Trash2 size={18} />
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })
                ) : (
                  <tr>
                    <td colSpan="3" className="text-center text-gray-400 py-6">
                      No roles found
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </div>
      </div>

      {/* Confirmation Modal */}
      {showConfirm && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-gray-900 bg-opacity-50">
          <div className="bg-white p-8 rounded-lg shadow-2xl max-w-sm text-center space-y-4">
            <h4 className="text-lg font-bold text-gray-800">Confirm Deletion</h4>
            <p className="text-gray-600">
              Are you sure you want to delete the role "<span className="font-semibold">{roleToDelete?.name}</span>"? This action cannot be undone.
            </p>
            <div className="flex justify-center gap-4 mt-4">
              <button
                onClick={handleCancelDelete}
                className="px-6 py-2 border rounded-lg text-gray-700 hover:bg-gray-100 transition"
              >
                Cancel
              </button>
              <button
                onClick={handleConfirmDelete}
                className="px-6 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 transition"
              >
                Delete
              </button>
            </div>
          </div>
        </div>
      )}
    </DashboardLayout>
  );
};

export default RoleForm;