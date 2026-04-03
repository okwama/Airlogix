import type { Passenger } from '../services/booking/bookingService';
import { bookingService } from '$lib/services/booking/bookingService';

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
    },

    setPassengers(p: Passenger[]) {
      passengers = p;
    },

    setStatus(s: BookingStatus) {
      status = s;
    },

    reset() {
      selectedFlight = null;
      reference = '';
      passengers = [];
      status = 'Pending';
      adultCount = 1;
      childCount = 0;
    }
  };
}

export const bookingStore = createBookingStore();
