import axios from 'axios';

const BASE_URL = 'http://192.168.22.222:8000';

const api = axios.create({ baseURL: BASE_URL });

// Attach token to every request if available
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('token');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

// On 401, redirect to login
api.interceptors.response.use(
  (res) => res,
  (err) => {
    if (err.response && err.response.status === 401) {
      localStorage.clear();
      window.location.href = '/';
    }
    return Promise.reject(err);
  }
);

export const login = async (username, password) => {
  const params = new URLSearchParams();
  params.append('username', username);
  params.append('password', password);
  const res = await api.post('/token', params);
  return res.data;
};

export const getMe = () => api.get('/users/me').then(r => r.data);
export const getSummary = () => api.get('/api/summary').then(r => r.data);
export const getStates = () => api.get('/api/states').then(r => r.data);
export const getDepartments = () => api.get('/api/departments').then(r => r.data);
export const getAnomalies = (dept) => api.get(`/api/anomalies/${dept}`).then(r => r.data);
export const getLeakage = (min = 50) => api.get(`/api/leakage?min_utilization=${min}`).then(r => r.data);
export const getReallocate = () => api.get('/api/reallocate').then(r => r.data);
export const getHighRisk = () => api.get('/api/high-risk').then(r => r.data);
export const getStateSummary = (state) => api.get(`/api/state/${state}`).then(r => r.data);

export default api;
