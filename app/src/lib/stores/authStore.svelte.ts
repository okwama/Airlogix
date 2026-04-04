import { authService } from '$lib/services/auth/authService';

interface AuthState {
  user: any | null;
  token: string | null;
  loading: boolean;
}

function createAuthStore() {
  const initialToken = authService.getToken();

  let state = $state<AuthState>({
    user: null,
    token: initialToken,
    loading: !!initialToken
  });

  async function init() {
    const token = authService.getToken();
    state = { ...state, token, loading: !!token };

    if (!token) {
      state = { ...state, loading: false };
      return;
    }

    try {
      const profile = await authService.fetchProfile();
      const refreshedToken = authService.getToken();
      if (!profile || !refreshedToken) {
        state = { user: null, token: null, loading: false };
        return;
      }
      state = { ...state, token: refreshedToken, user: profile, loading: false };
    } catch {
      authService.logout();
      state = { user: null, token: null, loading: false };
    }
  }

  async function login(identifier: string, password: string) {
    state = { ...state, loading: true };
    await authService.login({ identifier, password });
    const token = authService.getToken();
    const profile = await authService.fetchProfile();
    state = { user: profile, token, loading: false };
  }

  async function register(payload: {
    phone_number: string;
    password: string;
    first_name: string;
    last_name: string;
    email?: string;
  }) {
    state = { ...state, loading: true };
    await authService.register(payload);
    // After registration, immediately log in
    await login(payload.phone_number, payload.password);
  }

  async function refreshProfile() {
    const token = authService.getToken();
    if (!token) {
      state = { user: null, token: null, loading: false };
      return null;
    }

    const profile = await authService.fetchProfile();
    state = { ...state, token, user: profile, loading: false };
    return profile;
  }

  function setUser(user: any | null) {
    state = { ...state, user };
  }

  function logout() {
    authService.logout();
    try {
      if (typeof sessionStorage !== 'undefined') {
        const keysToRemove: string[] = [];
        for (let i = 0; i < sessionStorage.length; i++) {
          const key = sessionStorage.key(i);
          if (!key) continue;
          if (
            key.startsWith('booking_token:') ||
            key.startsWith('booking:') ||
            key.startsWith('cargo_token:') ||
            key.startsWith('cargo_auth:')
          ) {
            keysToRemove.push(key);
          }
        }
        keysToRemove.forEach((key) => sessionStorage.removeItem(key));
      }
    } catch {
      // ignore storage cleanup issues
    }
    state = { user: null, token: null, loading: false };
  }

  return {
    get user() {
      return state.user;
    },
    get token() {
      return state.token;
    },
    get loading() {
      return state.loading;
    },
    get isAuthenticated() {
      return !!state.token;
    },
    init,
    login,
    register,
    refreshProfile,
    setUser,
    logout
  };
}

export const authStore = createAuthStore();

