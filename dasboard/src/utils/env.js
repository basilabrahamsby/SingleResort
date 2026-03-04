export const isPommaDeployment = () => {
  if (typeof window === "undefined") {
    return false;
  }
  const path = window.location.pathname || "";
  return path.startsWith("/pommaadmin") || path.startsWith("/pommaholidays");
};

export const isOrchidDeployment = () => {
  if (typeof window === "undefined") {
    return false;
  }
  const path = window.location.pathname || "";
  return path.startsWith("/orchidadmin") || path.startsWith("/orchid");
};

export const isInventoryDeployment = () => {
  if (typeof window === "undefined") {
    return false;
  }
  const path = window.location.pathname || "";
  return path.startsWith("/inventory");
};

export const getMediaBaseUrl = () => {
  // For local development (localhost or 127.0.0.1 or LAN IP), always use port 8011 for Orchid
  if (typeof window !== "undefined") {
    const hostname = window.location.hostname || "";
    if (hostname === "localhost" || hostname === "127.0.0.1" || hostname.startsWith("192.168.") || hostname.startsWith("10.")) {
      return `http://${hostname}:8000`;
    }
  }

  // For production deployments
  if (typeof window !== "undefined" && isInventoryDeployment()) {
    return `${window.location.origin}/inventory`;
  }
  if (typeof window !== "undefined" && isOrchidDeployment()) {
    return `${window.location.origin}/orchidapi`;
  }
  if (typeof window !== "undefined" && isPommaDeployment()) {
    return `${window.location.origin}/pomma`;
  }
  if (process.env.REACT_APP_MEDIA_BASE_URL) {
    return process.env.REACT_APP_MEDIA_BASE_URL;
  }
  return process.env.NODE_ENV === "production"
    ? "https://www.teqmates.com/inventory/uploads"
    : "http://localhost:8000";
};

export const getApiBaseUrl = () => {
  // For local development (localhost or 127.0.0.1), ALWAYS use port 8011
  // This check MUST come FIRST, even before REACT_APP_API_BASE_URL
  // to override any environment variables for local development
  if (typeof window !== "undefined") {
    const hostname = window.location.hostname || "";
    const port = window.location.port || "";
    console.log("Hostname:", hostname, "Port:", port, "Pathname:", window.location.pathname);

    // Check if running on localhost or a local network IP (e.g. 192.168.x.x)
    if (hostname === "localhost" || hostname === "127.0.0.1" || hostname.startsWith("192.168.") || hostname.startsWith("10.")) {
      // Use the SAME hostname as the frontend, but port 8000
      const apiUrl = `http://${hostname}:8000/api`;
      console.log("Using dynamic local API URL:", apiUrl);
      return apiUrl;
    }
  }

  // Prefer explicit env override in all environments (dev/prod)
  // But only if not on localhost (checked above)
  if (process.env.REACT_APP_API_BASE_URL) {
    console.log("Using REACT_APP_API_BASE_URL:", process.env.REACT_APP_API_BASE_URL);
    return process.env.REACT_APP_API_BASE_URL;
  }

  // For production deployments (not localhost)
  if (typeof window !== "undefined" && isInventoryDeployment()) {
    const apiUrl = `${window.location.origin}/inventoryapi/api`;
    console.log("Using Inventory deployment API URL:", apiUrl);
    return apiUrl;
  }
  if (typeof window !== "undefined" && isOrchidDeployment()) {
    const apiUrl = `${window.location.origin}/orchidapi/api`;
    console.log("Using Orchid deployment API URL:", apiUrl);
    return apiUrl;
  }
  if (typeof window !== "undefined" && isPommaDeployment()) {
    const apiUrl = `${window.location.origin}/pommaapi/api`;
    console.log("Using Pomma deployment API URL:", apiUrl);
    return apiUrl;
  }
  // Sensible defaults
  const defaultUrl = process.env.NODE_ENV === "production"
    ? "https://www.teqmates.com/inventoryapi/api"
    : "http://localhost:8000/api";
  console.log("Using default API URL:", defaultUrl);
  return defaultUrl;
};
