import type { Passenger } from '../services/booking/bookingService';
import { browser } from '$app/environment';

export interface Flight {
  id?: string;
  flight_number: string;
  origin_iata: string;
  destination_iata: string;
  departure_time: string;
  arrival_time?: string;
  duration?: string;
  base_fare?: number;
  adult_fare?: number;
  child_fare?: number;
  infant_fare?: number;
  airline_name?: string;
}

export type BookingStatus = 'Pending' | 'Confirmed' | 'Cancelled';

function createBookingStore() {
  let selectedFlight = $state<Flight | null>(null);
  let reference = $state('');
  let passengers = $state<Passenger[]>([]);
  let status = $state<BookingStatus>('Pending');
  let adultCount = $state(1);
  let childCount = $state(0);

  const STORAGE_KEY = 'mc_booking_session';

  function save() {
    if (browser) {
      sessionStorage.setItem(STORAGE_KEY, JSON.stringify({
        selectedFlight,
        reference,
        passengers,
        status,
        adultCount,
        childCount
      }));
    }
  }

  function load() {
    if (browser) {
      const stored = sessionStorage.getItem(STORAGE_KEY);
      if (stored) {
        try {
          const data = JSON.parse(stored);
          selectedFlight = data.selectedFlight || null;
          reference = data.reference || '';
          passengers = data.passengers || [];
          status = data.status || 'Pending';
          adultCount = data.adultCount || 1;
          childCount = data.childCount || 0;
        } catch (e) {
          console.error('Failed to load booking session', e);
        }
      }
    }
  }

  // Load session from storage initially
  load();

  return {
    get selectedFlight() { return selectedFlight; },
    get reference() { return reference; },
    get passengers() { return passengers; },
    get status() { return status; },
    get adultCount() { return adultCount; },
    get childCount() { return childCount; },
    get totalPassengerCount() { return adultCount + childCount; },

    // Keeping for backward compatibility but using the new breakdown
    get passengerCount() { return adultCount + childCount; },

    setFlight(flight: Flight, adults = 1, children = 0) {
      selectedFlight = flight;
      adultCount = adults;
      childCount = children;
      
      const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      let res = '';
      for (let i = 0; i < 6; i++) res += chars.charAt(Math.floor(Math.random() * chars.length));
      reference = `MC-${res}`;
      save();
    },

    setPassengers(p: Passenger[]) {
      passengers = p;
      save();
    },

    setStatus(s: BookingStatus) {
      status = s;
      save();
    },

    reset() {
      selectedFlight = null;
      reference = '';
      passengers = [];
      status = 'Pending';
      adultCount = 1;
      childCount = 0;
      if (browser) {
        sessionStorage.removeItem(STORAGE_KEY);
      }
    }
  };
}

export const bookingStore = createBookingStore();
