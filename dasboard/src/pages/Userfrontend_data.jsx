import React, { useState, useEffect } from "react";
import DashboardLayout from "../layout/DashboardLayout";
import api from "../services/api";
import { toast } from "react-hot-toast";
import { FaStar, FaTrashAlt, FaPencilAlt, FaPlus, FaTimes, FaMapMarkerAlt, FaImage, FaInfoCircle, FaHeart, FaCamera, FaMapMarkedAlt } from "react-icons/fa";
import { AnimatePresence, motion } from "framer-motion";
import { getMediaBaseUrl } from "../utils/env";
import { getImageUrl } from "../utils/imageUtils";

// Utility moved to utils/imageUtils.js

// Utility moved to utils/imageUtils.js

const ensureHttpUrl = (url) => {
  if (!url) return "";
  return /^https?:\/\//i.test(url) ? url : `https://${url}`;
};

// Simplified Card Component
const ContentCard = ({ item, onEdit, onDelete, type }) => {
  const getIcon = () => {
    switch (type) {
      case 'banner': return <FaImage className="text-blue-500" />;
      case 'gallery': return <FaCamera className="text-purple-500" />;
      case 'review': return <FaStar className="text-yellow-500" />;
      case 'resortInfo': return <FaInfoCircle className="text-emerald-500" />;
      case 'signatureExperience': return <FaHeart className="text-pink-500" />;
      case 'planWedding': return <FaHeart className="text-rose-500" />;
      case 'nearbyAttraction': return <FaMapMarkedAlt className="text-indigo-500" />;
      default: return <FaImage className="text-gray-500" />;
    }
  };

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      whileHover={{ y: -5 }}
      className="bg-white rounded-2xl shadow-[0_8px_30px_rgb(0,0,0,0.04)] hover:shadow-[0_20px_50px_rgba(0,0,0,0.1)] transition-all duration-500 overflow-hidden border border-gray-100/50 group"
    >
      <div className="relative h-52 overflow-hidden bg-slate-100">
        {item.image_url ? (
          <img
            src={getImageUrl(item.image_url)}
            alt={item.title || item.caption || item.name || 'Content'}
            className="w-full h-full object-cover group-hover:scale-110 transition-transform duration-700 ease-out"
            onError={(e) => {
              e.target.src = 'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgeG1sbnM9Imh0dHA6Ly93d3cudzMub3JnLzIwMDAvc3ZnIj48cmVjdCB3aWR0aD0iMjAwIiBoZWlnaHQ9IjIwMCIgZmlsbD0iI2YzZjRmNiIvPjx0ZXh0IHg9IjUwJSIgeT0iNTAlIiBmb250LWZhbWlseT0iQXJpYWwiIGZvbnQtc2l6ZT0iMTIiIGZpbGw9IiM5Y2EzYWYiIHRleHQtYW5jaG9yPSJtaWRkbGUiIGR5PSIuM2VtIj5ObyBJbWFnZTwvdGV4dD48L3N2Zz4=';
            }}
          />
        ) : (
          <div className="w-full h-full flex flex-col items-center justify-center text-gray-400 bg-gray-50">
            <FaImage size={40} className="mb-2 opacity-20" />
            <span className="text-xs uppercase tracking-widest font-medium opacity-40">No Image</span>
          </div>
        )}
        <div className="absolute top-4 left-4 bg-white/90 backdrop-blur-md p-2 rounded-xl shadow-sm">
          {getIcon()}
        </div>

        {item.is_active !== undefined && (
          <div className="absolute top-4 right-4">
            <span className={`px-3 py-1.5 rounded-full text-[10px] font-bold tracking-wider uppercase backdrop-blur-md shadow-sm border ${item.is_active
              ? 'bg-emerald-500/90 text-white border-emerald-400'
              : 'bg-rose-500/90 text-white border-rose-400'
              }`}>
              {item.is_active ? 'Active' : 'Hidden'}
            </span>
          </div>
        )}

        {/* Subtle overlay */}
        <div className="absolute inset-0 bg-gradient-to-t from-black/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity duration-500" />
      </div>

      <div className="p-5 flex flex-col h-full">
        <div className="mb-4">
          <h3 className="font-bold text-slate-800 mb-1.5 leading-tight text-lg min-h-[1.5rem] line-clamp-1">
            {item.title || item.name || item.caption || 'Untitled Entry'}
          </h3>
          {(item.subtitle || item.description || item.comment) && (
            <p className="text-sm text-slate-500 line-clamp-2 leading-relaxed h-10">
              {item.subtitle || item.description || (item.comment ? `"${item.comment}"` : '')}
            </p>
          )}
        </div>

        {item.rating && (
          <div className="flex text-amber-400 mb-4 bg-amber-50/50 w-fit px-2 py-1 rounded-lg">
            {[...Array(5)].map((_, i) => (
              <FaStar key={i} size={12} className={i < item.rating ? 'fill-current' : 'text-gray-200'} />
            ))}
          </div>
        )}

        <div className="flex gap-3 mt-auto pt-4 border-t border-slate-50">
          <button
            onClick={() => onEdit(item)}
            className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-indigo-50 text-indigo-600 rounded-xl hover:bg-indigo-600 hover:text-white transition-all duration-300 text-xs font-bold uppercase tracking-wider shadow-sm hover:shadow-indigo-200"
          >
            <FaPencilAlt size={12} /> Edit
          </button>
          <button
            onClick={() => onDelete(item.id)}
            className="flex-none p-2.5 bg-rose-50 text-rose-500 rounded-xl hover:bg-rose-500 hover:text-white transition-all duration-300 shadow-sm hover:shadow-rose-100"
            title="Delete Content"
          >
            <FaTrashAlt size={14} />
          </button>
        </div>
      </div>
    </motion.div>
  );
};

// Simplified Modal
const SimpleModal = ({ isOpen, onClose, onSubmit, fields, initialData, title, isMultipart = false }) => {
  const [formState, setFormState] = useState({});
  const [selectedFile, setSelectedFile] = useState(null);
  const [imagePreview, setImagePreview] = useState(null);
  const [isLoading, setIsLoading] = useState(false);

  useEffect(() => {
    if (initialData) {
      setFormState(initialData);
      if (initialData.image_url) {
        setImagePreview(getImageUrl(initialData.image_url));
      } else {
        setImagePreview(null);
      }
    } else {
      setFormState({});
      setImagePreview(null);
      setSelectedFile(null);
    }
  }, [initialData, isOpen]);

  const handleFormChange = (e) => {
    const { name, value, type, checked, files } = e.target;
    if (type === 'file' && files.length > 0) {
      setSelectedFile(files[0]);
      setImagePreview(URL.createObjectURL(files[0]));
      setFormState({ ...formState, [name]: files[0] });
    } else if (type === 'checkbox') {
      setFormState({ ...formState, [name]: checked });
    } else {
      setFormState({ ...formState, [name]: value });
    }
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setIsLoading(true);
    try {
      await onSubmit(formState, selectedFile);
      onClose();
    } finally {
      setIsLoading(false);
    }
  };

  if (!isOpen) return null;

  return (
    <AnimatePresence>
      <motion.div
        initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }}
        className="fixed inset-0 bg-slate-900/60 backdrop-blur-sm flex justify-center items-center z-[100] p-4"
        onClick={onClose}
      >
        <motion.div
          initial={{ scale: 0.95, opacity: 0, y: 20 }}
          animate={{ scale: 1, opacity: 1, y: 0 }}
          exit={{ scale: 0.95, opacity: 0, y: 20 }}
          className="bg-white rounded-[2rem] shadow-2xl w-full max-w-[500px] max-h-[92vh] flex flex-col overflow-hidden"
          onClick={(e) => e.stopPropagation()}
        >
          {/* Modal Header */}
          <div className="p-8 pb-4 flex items-center justify-between">
            <div>
              <h2 className="text-2xl font-black text-slate-800 tracking-tight">{title}</h2>
              <p className="text-sm text-slate-500 mt-1">Fill in the details for your website content.</p>
            </div>
            <button
              onClick={onClose}
              className="p-2.5 bg-slate-50 text-slate-400 hover:text-slate-600 hover:bg-slate-100 rounded-full transition-all"
            >
              <FaTimes size={18} />
            </button>
          </div>

          <div className="flex-1 overflow-y-auto px-8 pb-8 pt-2">
            <form onSubmit={handleSubmit} className="space-y-6">
              {fields.map(field => (
                <div key={field.name}>
                  <label className="block text-[11px] font-black uppercase tracking-widest text-slate-400 mb-2 ml-1">
                    {field.placeholder || field.name.replace('_', ' ')}
                  </label>
                  {field.type === 'file' ? (
                    <div className="relative group/file">
                      <div className={`w-full h-40 rounded-2xl border-2 border-dashed transition-all flex flex-col items-center justify-center p-4 overflow-hidden ${imagePreview ? 'border-indigo-200 bg-indigo-50/20' : 'border-slate-200 bg-slate-50 group-hover/file:bg-slate-100 group-hover/file:border-indigo-300'
                        }`}>
                        {imagePreview ? (
                          <>
                            <img src={imagePreview} alt="Preview" className="absolute inset-0 w-full h-full object-cover" />
                            <div className="absolute inset-0 bg-black/40 opacity-0 group-hover/file:opacity-100 transition-opacity flex items-center justify-center backdrop-blur-[2px]">
                              <p className="text-white text-xs font-bold uppercase tracking-wider">Change Image</p>
                            </div>
                          </>
                        ) : (
                          <>
                            <div className="p-3 bg-white rounded-xl shadow-sm mb-2 text-indigo-500">
                              <FaCamera size={24} />
                            </div>
                            <p className="text-xs font-bold text-slate-500 uppercase tracking-widest">Select Image Asset</p>
                          </>
                        )}
                        <input
                          type="file"
                          name={field.name}
                          onChange={handleFormChange}
                          accept="image/*"
                          className="absolute inset-0 opacity-0 cursor-pointer"
                        />
                      </div>
                    </div>
                  ) : field.type === 'checkbox' ? (
                    <label className="flex items-center gap-3 cursor-pointer group/check bg-slate-50 p-4 rounded-2xl border border-transparent hover:border-indigo-200 transition-all">
                      <div className={`w-6 h-6 rounded-lg border-2 flex items-center justify-center transition-all ${formState[field.name] ? 'bg-indigo-600 border-indigo-600' : 'border-slate-300'
                        }`}>
                        {formState[field.name] && <div className="w-2.5 h-2.5 bg-white rounded-full shadow-sm" />}
                      </div>
                      <input
                        type="checkbox"
                        name={field.name}
                        checked={!!formState[field.name]}
                        onChange={handleFormChange}
                        className="hidden"
                      />
                      <span className="text-sm font-bold text-slate-700 uppercase tracking-widest">Set as Active</span>
                    </label>
                  ) : field.type === 'textarea' ? (
                    <textarea
                      name={field.name}
                      placeholder={`Enter ${field.placeholder.toLowerCase()} here...`}
                      value={formState[field.name] || ''}
                      onChange={handleFormChange}
                      required={field.required !== false}
                      rows={4}
                      className="w-full px-5 py-4 bg-slate-50 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-indigo-500/10 focus:border-indigo-500 transition-all resize-none shadow-inner"
                    />
                  ) : (
                    <input
                      type={field.type || "text"}
                      name={field.name}
                      placeholder={`Enter ${field.placeholder.toLowerCase()}...`}
                      value={formState[field.name] || ''}
                      onChange={handleFormChange}
                      required={field.required !== false}
                      className="w-full px-5 py-4 bg-slate-50 border border-slate-200 rounded-2xl focus:ring-4 focus:ring-indigo-500/10 focus:border-indigo-500 transition-all shadow-inner"
                    />
                  )}
                </div>
              ))}
              <div className="pt-4">
                <button
                  type="submit"
                  disabled={isLoading}
                  className="w-full py-5 px-6 bg-gradient-to-r from-indigo-600 to-indigo-700 text-white rounded-2xl font-black uppercase tracking-[0.2em] shadow-[0_10px_30px_rgba(79,70,229,0.3)] hover:shadow-[0_15px_40px_rgba(79,70,229,0.4)] hover:-translate-y-1 transition-all duration-300 disabled:opacity-50 disabled:translate-y-0"
                >
                  {isLoading ? (
                    <span className="flex items-center justify-center gap-2">
                      <div className="w-4 h-4 border-2 border-white/20 border-t-white rounded-full animate-spin" />
                      Saving Changes...
                    </span>
                  ) : "Confirm & Save"}
                </button>
              </div>
            </form>
          </div>
        </motion.div>
      </motion.div>
    </AnimatePresence>
  );
};

// Main Component
export default function ResortCMS() {
  const [resortData, setResortData] = useState({
    banners: [],
    gallery: [],
    reviews: [],
    resortInfo: [],
    signatureExperiences: [],
    planWeddings: [],
    nearbyAttractions: [],
    nearbyAttractionBanners: [],
  });
  const [isLoading, setIsLoading] = useState(true);
  const [modalState, setModalState] = useState({ isOpen: false, config: null, initialData: null });
  const [activeSection, setActiveSection] = useState('banners');

  const fetchAll = async () => {
    setIsLoading(true);
    try {
      const [
        bannersRes, galleryRes, reviewsRes, resortInfoRes,
        signatureExpRes, planWeddingRes, nearbyAttrRes, nearbyAttrBannerRes
      ] = await Promise.all([
        api.get("/header-banner/").catch(() => ({ data: [] })),
        api.get("/gallery/").catch(() => ({ data: [] })),
        api.get("/reviews/").catch(() => ({ data: [] })),
        api.get("/resort-info/").catch(() => ({ data: [] })),
        api.get("/signature-experiences/").catch(() => ({ data: [] })),
        api.get("/plan-weddings/").catch(() => ({ data: [] })),
        api.get("/nearby-attractions/").catch(() => ({ data: [] })),
        api.get("/nearby-attraction-banners/").catch(() => ({ data: [] })),
      ]);
      setResortData({
        banners: bannersRes.data || [],
        gallery: galleryRes.data || [],
        reviews: reviewsRes.data || [],
        resortInfo: resortInfoRes.data || [],
        signatureExperiences: signatureExpRes.data || [],
        planWeddings: planWeddingRes.data || [],
        nearbyAttractions: nearbyAttrRes.data || [],
        nearbyAttractionBanners: nearbyAttrBannerRes.data || [],
      });
    } catch (error) {
      console.error("Failed to fetch data:", error);
      toast.error("Some content could not be loaded.");
    } finally {
      setIsLoading(false);
    }
  };

  useEffect(() => {
    fetchAll();
  }, []);

  const handleDelete = async (endpoint, id, name) => {
    if (window.confirm(`Are you sure you want to permanently delete this ${name}?`)) {
      try {
        const cleanEndpoint = endpoint.endsWith('/') ? endpoint.slice(0, -1) : endpoint;
        await api.delete(`${cleanEndpoint}/${id}`);
        toast.success("Content removed successfully!");
        fetchAll();
      } catch (err) {
        toast.error(err.response?.data?.detail || `Failed to delete content`);
      }
    }
  };

  const handleFormSubmit = async (config, initialData, formData, file) => {
    const isEditing = initialData && initialData.id;
    const endpoint = isEditing ? `${config.endpoint}${initialData.id}` : config.endpoint;
    const method = isEditing ? 'put' : 'post';

    let payload = formData;
    if (config.isMultipart) {
      const data = new FormData();
      Object.keys(formData).forEach(key => {
        if (key !== 'image') {
          const value = formData[key];
          data.append(key, typeof value === 'boolean' ? String(value) : value);
        }
      });
      if (file) data.append('image', file);
      payload = data;
    } else {
      const cleanData = { ...formData };
      delete cleanData.id; // Prevent sending ID in body for cleanup
      if (cleanData.rating !== undefined) cleanData.rating = parseInt(cleanData.rating, 10);
      if (cleanData.is_active !== undefined) {
        cleanData.is_active = cleanData.is_active === true || cleanData.is_active === 'true';
      }
      payload = cleanData;
    }

    try {
      console.log(`Submitting to ${endpoint} via ${method}`);
      await api({ method, url: endpoint, data: payload });
      toast.success(`${config.title} saved successfully!`);
      setModalState({ isOpen: false, config: null, initialData: null });
      fetchAll();
    } catch (error) {
      console.error("Form submit error:", error);
      toast.error(error.response?.data?.detail || "Failed to save content. Check all fields.");
    }
  };

  const sectionConfigs = {
    banners: {
      title: "Header Banner",
      endpoint: "/header-banner/",
      fields: [
        { name: "title", placeholder: "Display Title" },
        { name: "subtitle", placeholder: "Short Subtitle / Tagline" },
        { name: "image", type: "file" },
        { name: "is_active", type: "checkbox", placeholder: "Show on Website" }
      ],
      isMultipart: true
    },
    gallery: {
      title: "Gallery Image",
      endpoint: "/gallery/",
      fields: [
        { name: "caption", placeholder: "Image Caption" },
        { name: "image", type: "file" }
      ],
      isMultipart: true
    },
    reviews: {
      title: "Review",
      endpoint: "/reviews/",
      fields: [
        { name: "name", placeholder: "Guest Name" },
        { name: "comment", placeholder: "Review Text", type: "textarea" },
        { name: "rating", placeholder: "Rating (1-5)", type: "number" }
      ],
      isMultipart: false
    },
    resortInfo: {
      title: "Resort Detail",
      endpoint: "/resort-info/",
      fields: [
        { name: "name", placeholder: "Official Brand Name" },
        { name: "address", placeholder: "Physical Address", type: "textarea" },
        { name: "facebook", placeholder: "Facebook Link" },
        { name: "instagram", placeholder: "Instagram Link" },
        { name: "twitter", placeholder: "Twitter Link" },
        { name: "linkedin", placeholder: "LinkedIn Link" },
        { name: "is_active", type: "checkbox", placeholder: "System Default" }
      ],
      isMultipart: false
    },
    signatureExperiences: {
      title: "Signature Experience",
      endpoint: "/signature-experiences/",
      fields: [
        { name: "title", placeholder: "Experience Title" },
        { name: "description", placeholder: "Extended Description", type: "textarea" },
        { name: "image", type: "file" },
        { name: "is_active", type: "checkbox", placeholder: "Active Status" }
      ],
      isMultipart: true
    },
    planWeddings: {
      title: "Wedding Scene",
      endpoint: "/plan-weddings/",
      fields: [
        { name: "title", placeholder: "Venue/Event Name" },
        { name: "description", placeholder: "Details", type: "textarea" },
        { name: "image", type: "file" },
        { name: "is_active", type: "checkbox", placeholder: "Active" }
      ],
      isMultipart: true
    },
    nearbyAttractions: {
      title: "Local Attraction",
      endpoint: "/nearby-attractions/",
      fields: [
        { name: "title", placeholder: "Name of Place" },
        { name: "description", placeholder: "About this place", type: "textarea" },
        { name: "map_link", placeholder: "Google Maps Embed Link" },
        { name: "image", type: "file" },
        { name: "is_active", type: "checkbox", placeholder: "Visible" }
      ],
      isMultipart: true
    },
    nearbyAttractionBanners: {
      title: "Attraction Banner",
      endpoint: "/nearby-attraction-banners/",
      fields: [
        { name: "title", placeholder: "Heading" },
        { name: "subtitle", placeholder: "Sub-heading", type: "textarea" },
        { name: "image", type: "file" },
        { name: "is_active", type: "checkbox", placeholder: "Status" }
      ],
      isMultipart: true
    },
  };

  const sections = [
    { key: 'banners', label: 'Banners', icon: <FaImage />, data: resortData.banners },
    { key: 'gallery', label: 'Gallery', icon: <FaCamera />, data: resortData.gallery },
    { key: 'reviews', label: 'Reviews', icon: <FaStar />, data: resortData.reviews },
    { key: 'resortInfo', label: 'Resort Info', icon: <FaInfoCircle />, data: resortData.resortInfo },
    { key: 'signatureExperiences', label: 'Experiences', icon: <FaHeart />, data: resortData.signatureExperiences },
    { key: 'planWeddings', label: 'Weddings', icon: <FaHeart />, data: resortData.planWeddings },
    { key: 'nearbyAttractions', label: 'Attractions', icon: <FaMapMarkedAlt />, data: resortData.nearbyAttractions },
    { key: 'nearbyAttractionBanners', label: 'Attr Banners', icon: <FaImage />, data: resortData.nearbyAttractionBanners },
  ];

  const currentSection = sections.find(s => s.key === activeSection);
  const currentConfig = sectionConfigs[activeSection];

  if (isLoading) {
    return (
      <DashboardLayout>
        <div className="flex items-center justify-center min-h-[70vh]">
          <div className="text-center">
            <div className="w-16 h-16 border-4 border-indigo-100 border-t-indigo-600 rounded-full animate-spin mx-auto mb-6 shadow-indigo-100 shadow-xl"></div>
            <p className="text-slate-400 font-black uppercase tracking-widest text-xs">Authenticating Data...</p>
          </div>
        </div>
      </DashboardLayout>
    );
  }

  return (
    <DashboardLayout>
      <div className="p-4 sm:p-8 bg-[#F8FAFC] min-h-screen">
        {/* Header Overlay */}
        <div className="max-w-[1600px] mx-auto">
          <div className="mb-12 flex flex-col md:flex-row md:items-end justify-between gap-6">
            <div>
              <motion.h1
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                className="text-4xl font-black text-slate-900 tracking-tight"
              >
                Website <span className="text-indigo-600">Console</span>
              </motion.h1>
              <motion.p
                initial={{ opacity: 0, x: -20 }}
                animate={{ opacity: 1, x: 0 }}
                transition={{ delay: 0.1 }}
                className="text-slate-500 mt-2 font-medium"
              >
                Curate and manage your resort's digital presence.
              </motion.p>
            </div>

            <motion.button
              initial={{ opacity: 0, scale: 0.9 }}
              animate={{ opacity: 1, scale: 1 }}
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              onClick={() => setModalState({ isOpen: true, config: currentConfig, initialData: null })}
              className="flex items-center justify-center gap-3 px-8 py-4 bg-slate-900 text-white rounded-[1.25rem] font-black uppercase tracking-[0.1em] text-xs shadow-2xl shadow-slate-200 hover:bg-slate-800 transition-all"
            >
              <FaPlus size={12} className="text-indigo-400" />
              Create {currentConfig?.title}
            </motion.button>
          </div>

          {/* Navigation Navigation Tabs */}
          <div className="mb-10 overflow-x-auto pb-4 scrollbar-hide">
            <div className="flex gap-3 bg-white/60 backdrop-blur-md p-2 rounded-[2rem] shadow-[0_4px_20px_rgba(0,0,0,0.03)] border border-white w-max">
              {sections.map(section => (
                <button
                  key={section.key}
                  onClick={() => setActiveSection(section.key)}
                  className={`flex items-center gap-3 px-6 py-3 rounded-2xl font-black text-[11px] uppercase tracking-widest transition-all duration-300 ${activeSection === section.key
                    ? 'bg-white text-indigo-600 shadow-[0_10px_30px_rgba(0,0,0,0.08)] border border-indigo-50'
                    : 'text-slate-400 hover:text-slate-600 hover:bg-white/40'
                    }`}
                >
                  <span className={activeSection === section.key ? 'text-indigo-500' : 'text-slate-300'}>
                    {section.icon}
                  </span>
                  <span>{section.label}</span>
                  {section.data.length > 0 && (
                    <span className={`ml-1 w-5 h-5 flex items-center justify-center rounded-lg text-[9px] ${activeSection === section.key
                      ? 'bg-indigo-600 text-white'
                      : 'bg-slate-100 text-slate-500'
                      }`}>
                      {section.data.length}
                    </span>
                  )}
                </button>
              ))}
            </div>
          </div>

          {/* Content Display */}
          <AnimatePresence mode="wait">
            <motion.div
              key={activeSection}
              initial={{ opacity: 0, y: 10 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -10 }}
              transition={{ duration: 0.4 }}
            >
              {currentSection.data.length > 0 ? (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-8">
                  {currentSection.data.map((item, idx) => (
                    <ContentCard
                      key={item.id}
                      item={item}
                      type={activeSection}
                      onEdit={(item) => setModalState({ isOpen: true, config: currentConfig, initialData: item })}
                      onDelete={(id) => handleDelete(currentConfig.endpoint, id, currentConfig.title)}
                    />
                  ))}
                </div>
              ) : (
                <div className="bg-white rounded-[3rem] p-20 text-center border-2 border-dashed border-slate-100 shadow-sm flex flex-col items-center">
                  <div className="w-24 h-24 bg-slate-50 rounded-full flex items-center justify-center text-slate-200 mb-8">
                    {React.cloneElement(currentSection.icon, { size: 40 })}
                  </div>
                  <h3 className="text-2xl font-black text-slate-800 tracking-tight mb-2">
                    No {currentConfig?.title} Entries
                  </h3>
                  <p className="text-slate-400 font-medium max-w-[300px] mx-auto text-sm leading-relaxed mb-10">
                    Your website's {currentSection.label.toLowerCase()} section is currently empty. Start by creating a new entry.
                  </p>
                  <button
                    onClick={() => setModalState({ isOpen: true, config: currentConfig, initialData: null })}
                    className="px-8 py-4 bg-indigo-50 text-indigo-600 rounded-2xl font-black uppercase tracking-widest text-[10px] hover:bg-indigo-600 hover:text-white transition-all shadow-sm"
                  >
                    Get Started
                  </button>
                </div>
              )}
            </motion.div>
          </AnimatePresence>
        </div>

        {/* CMS Modal */}
        <SimpleModal
          isOpen={modalState.isOpen}
          onClose={() => setModalState({ isOpen: false, config: null, initialData: null })}
          onSubmit={(data, file) => handleFormSubmit(modalState.config, modalState.initialData, data, file)}
          fields={modalState.config?.fields || []}
          initialData={modalState.initialData}
          title={`${modalState.initialData ? 'Update' : 'Generate'} ${modalState.config?.title}`}
          isMultipart={modalState.config?.isMultipart}
        />
      </div>
    </DashboardLayout>
  );
}
