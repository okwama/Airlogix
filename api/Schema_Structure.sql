-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Jun 05, 2026 at 11:28 AM
-- Server version: 10.6.25-MariaDB-cll-lve
-- PHP Version: 8.4.21

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `impulsep_air`
--

-- --------------------------------------------------------

--
-- Table structure for table `accounts`
--

CREATE TABLE `accounts` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `code` varchar(50) NOT NULL,
  `currency` varchar(3) DEFAULT NULL,
  `balance` decimal(10,2) NOT NULL DEFAULT 0.00,
  `status` varchar(50) NOT NULL DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `account_category`
--

CREATE TABLE `account_category` (
  `id` int(3) NOT NULL,
  `name` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `account_deletion_requests`
--

CREATE TABLE `account_deletion_requests` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `full_name` varchar(150) NOT NULL,
  `email` varchar(150) NOT NULL,
  `reason` text DEFAULT NULL,
  `status` enum('pending','processed') DEFAULT 'pending',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `account_ledger`
--

CREATE TABLE `account_ledger` (
  `id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `transaction_date` date NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `debit` decimal(10,2) NOT NULL DEFAULT 0.00,
  `credit` decimal(10,2) NOT NULL DEFAULT 0.00,
  `balance` decimal(10,2) NOT NULL,
  `reference` varchar(100) DEFAULT NULL,
  `payment_method` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `account_types`
--

CREATE TABLE `account_types` (
  `id` int(11) NOT NULL,
  `account_type` varchar(100) NOT NULL,
  `account_category` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `agencies`
--

CREATE TABLE `agencies` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `contact` varchar(50) DEFAULT NULL,
  `city` varchar(100) DEFAULT NULL,
  `country` varchar(100) DEFAULT NULL,
  `password_hash` varchar(255) DEFAULT NULL COMMENT 'bcrypt hash — replaces plaintext password column',
  `email` varchar(30) NOT NULL,
  `booking_limit` int(11) DEFAULT NULL,
  `credit_limit` decimal(10,2) DEFAULT NULL,
  `max_pax_per_booking` int(11) DEFAULT NULL,
  `default_currency` varchar(3) DEFAULT NULL,
  `credit_days` int(11) DEFAULT NULL,
  `payment_limit` decimal(10,2) DEFAULT NULL,
  `balance` decimal(10,2) NOT NULL DEFAULT 0.00,
  `commission_percentage` decimal(5,2) DEFAULT NULL,
  `status` enum('active','suspended','deleted') NOT NULL DEFAULT 'active' COMMENT 'Portal access control',
  `logo_url` varchar(512) DEFAULT NULL COMMENT 'Agency branding on PDF tickets',
  `min_float_threshold` decimal(15,2) DEFAULT 50000.00 COMMENT 'KES — new bookings blocked below this amount',
  `last_login_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `agency_deposits`
--

CREATE TABLE `agency_deposits` (
  `id` int(11) NOT NULL,
  `agency_id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `amount` decimal(15,2) NOT NULL,
  `date_paid` date NOT NULL,
  `description` text NOT NULL,
  `payment_method` varchar(50) NOT NULL,
  `reference` varchar(100) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `agency_ledger`
--

CREATE TABLE `agency_ledger` (
  `id` int(11) NOT NULL,
  `agency_id` int(11) NOT NULL,
  `transaction_type` enum('booking_debit','refund_credit','commission_credit','manual_adjustment','float_topup','penalty_fee','markup_credit') NOT NULL DEFAULT 'manual_adjustment',
  `transaction_date` date NOT NULL,
  `description` text DEFAULT NULL,
  `debit` decimal(15,2) NOT NULL DEFAULT 0.00,
  `credit` decimal(15,2) NOT NULL DEFAULT 0.00,
  `balance` decimal(15,2) NOT NULL DEFAULT 0.00,
  `booking_id` int(11) DEFAULT NULL COMMENT 'bookings.id — present on booking_debit / refund_credit',
  `created_by` int(11) DEFAULT NULL COMMENT 'admin user id who posted manual entries',
  `reference` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `agents`
--

CREATE TABLE `agents` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `country` varchar(100) DEFAULT NULL,
  `contact` varchar(50) DEFAULT NULL,
  `agency_id` int(11) DEFAULT NULL,
  `use_deposit` tinyint(1) DEFAULT 0,
  `status` enum('active','suspended','deleted') NOT NULL DEFAULT 'active',
  `is_independent` tinyint(1) NOT NULL DEFAULT 0 COMMENT '1 = independent agent; behaves as own agency',
  `markup_pct` decimal(5,2) DEFAULT 0.00 COMMENT 'Percentage markup applied on top of base fare',
  `balance` decimal(15,2) DEFAULT 0.00 COMMENT 'Float balance — used only when is_independent = 1',
  `min_float_threshold` decimal(15,2) DEFAULT 50000.00 COMMENT 'KES — new bookings blocked below this amount',
  `last_login_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `password_hash` varchar(255) DEFAULT NULL COMMENT 'bcrypt hash — replaces plaintext password column',
  `password` varchar(255) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `agent_commissions`
--

CREATE TABLE `agent_commissions` (
  `id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `agent_id` int(11) NOT NULL,
  `agency_id` int(11) DEFAULT NULL,
  `base_fare` decimal(10,2) NOT NULL COMMENT 'Fare before markup',
  `markup_pct` decimal(5,2) DEFAULT 0.00,
  `markup_amount` decimal(10,2) DEFAULT 0.00 COMMENT 'base_fare * markup_pct / 100',
  `commission_pct` decimal(5,2) DEFAULT 0.00,
  `commission_amount` decimal(10,2) DEFAULT 0.00,
  `status` enum('pending','confirmed','paid','reversed') NOT NULL DEFAULT 'pending',
  `paid_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Per-booking commission and markup records for agents';

-- --------------------------------------------------------

--
-- Table structure for table `aircrafts`
--

CREATE TABLE `aircrafts` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `registration` varchar(50) NOT NULL,
  `capacity` int(11) DEFAULT NULL,
  `max_cargo_weight` decimal(10,2) DEFAULT NULL,
  `category_id` int(11) DEFAULT NULL,
  `created_by` varchar(255) DEFAULT NULL,
  `status` varchar(50) NOT NULL DEFAULT 'active',
  `calendar_color` varchar(7) DEFAULT '#3B82F6',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `airline_users`
--

CREATE TABLE `airline_users` (
  `id` int(11) NOT NULL,
  `phone_number` varchar(20) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `password_hash` varchar(255) NOT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `last_name` varchar(100) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `nationality` varchar(100) DEFAULT NULL,
  `passport_number` varchar(50) DEFAULT NULL,
  `passport_expiry_date` date DEFAULT NULL,
  `frequent_flyer_number` varchar(50) DEFAULT NULL,
  `member_club` enum('BRONZE','SILVER','GOLD','PLATINUM') NOT NULL DEFAULT 'BRONZE',
  `loyalty_points` int(11) NOT NULL DEFAULT 0,
  `profile_photo_url` varchar(512) DEFAULT NULL,
  `status` enum('active','suspended','deleted') DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `password_reset_code` varchar(6) DEFAULT NULL,
  `password_reset_expires_at` datetime DEFAULT NULL,
  `deletion_status` enum('active','pending','deleted') DEFAULT 'active'
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `bookings`
--

CREATE TABLE `bookings` (
  `id` int(11) NOT NULL,
  `booking_reference` varchar(50) NOT NULL,
  `pnr` varchar(20) DEFAULT NULL COMMENT 'PNR issued by airline system on ticketing',
  `source` enum('web','mobile','portal') DEFAULT 'web' COMMENT 'Which system created this booking',
  `flight_series_id` int(11) NOT NULL,
  `flight_id` int(11) DEFAULT NULL,
  `cabin_class_id` int(11) DEFAULT NULL,
  `passenger_id` int(11) DEFAULT NULL,
  `passenger_name` varchar(255) NOT NULL,
  `passenger_email` varchar(255) DEFAULT NULL,
  `passenger_phone` varchar(50) DEFAULT NULL,
  `passenger_type` varchar(20) NOT NULL,
  `number_of_passengers` int(11) NOT NULL DEFAULT 1,
  `fare_per_passenger` decimal(10,2) NOT NULL,
  `base_fare` decimal(10,2) DEFAULT NULL,
  `taxes_amount` decimal(10,2) DEFAULT NULL,
  `revenue_recognized` tinyint(1) NOT NULL DEFAULT 0,
  `total_amount` decimal(10,2) NOT NULL,
  `payment_method` varchar(50) NOT NULL,
  `payment_status` varchar(50) NOT NULL DEFAULT 'pending',
  `payment_reference` varchar(100) DEFAULT NULL,
  `payment_account` varchar(100) DEFAULT NULL,
  `status` tinyint(4) DEFAULT 0 COMMENT '0:Pending, 1:Confirmed, 2:Cancelled, 3:Partial',
  `booking_date` date NOT NULL,
  `reservation_expires_at` datetime DEFAULT NULL,
  `expired_at` datetime DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `is_return_trip` tinyint(1) NOT NULL DEFAULT 0,
  `return_date` date DEFAULT NULL,
  `return_flight_series_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `agent_id` int(11) DEFAULT NULL COMMENT 'agents.id — set when booking made via portal',
  `agency_id` int(11) DEFAULT NULL COMMENT 'agencies.id — set when booking made via portal',
  `markup_amount` decimal(10,2) DEFAULT 0.00 COMMENT 'Agent markup applied over base fare',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `booking_amendments`
--

CREATE TABLE `booking_amendments` (
  `id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `amendment_type` enum('date_change','name_correction','route_change','upgrade','cancellation','other') NOT NULL,
  `requested_by_type` enum('agent','agency') NOT NULL,
  `requested_by_id` int(11) NOT NULL,
  `status` enum('pending','approved','rejected','completed') NOT NULL DEFAULT 'pending',
  `old_value` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Snapshot of fields before the change' CHECK (json_valid(`old_value`)),
  `new_value` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL COMMENT 'Snapshot of fields after the change' CHECK (json_valid(`new_value`)),
  `penalty_fee` decimal(10,2) DEFAULT 0.00,
  `additional_fare` decimal(10,2) DEFAULT 0.00 COMMENT 'Extra fare due to upgrade/route change',
  `agent_notes` text DEFAULT NULL,
  `admin_notes` text DEFAULT NULL,
  `processed_by` int(11) DEFAULT NULL,
  `processed_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Booking amendment requests with before/after snapshots';

-- --------------------------------------------------------

--
-- Table structure for table `booking_passengers`
--

CREATE TABLE `booking_passengers` (
  `id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `flight_series_id` int(11) DEFAULT NULL,
  `flight_id` int(11) DEFAULT NULL,
  `passenger_id` int(11) NOT NULL,
  `passenger_type` varchar(20) NOT NULL,
  `fare_amount` decimal(10,2) NOT NULL,
  `travel_date` date DEFAULT NULL,
  `leg` varchar(20) NOT NULL DEFAULT 'outbound',
  `return_travel_date` date DEFAULT NULL,
  `return_flight_series_id` int(11) DEFAULT NULL,
  `ticket_number` varchar(20) DEFAULT NULL,
  `ticket_status` enum('OPEN','USED','VOID','REFUNDED') DEFAULT 'OPEN',
  `status` varchar(30) DEFAULT 'confirmed',
  `payment_reference` varchar(100) DEFAULT NULL,
  `payment_account` varchar(100) DEFAULT NULL,
  `issued_at` timestamp NULL DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `booking_status_history`
--

CREATE TABLE `booking_status_history` (
  `id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `from_status` varchar(50) DEFAULT NULL COMMENT 'NULL on initial creation',
  `to_status` varchar(50) NOT NULL,
  `changed_by_type` enum('agent','agency','system','admin') NOT NULL DEFAULT 'system',
  `changed_by_id` int(11) DEFAULT NULL,
  `reason` text DEFAULT NULL COMMENT 'Optional reason / notes for change',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Immutable audit trail of booking status transitions';

-- --------------------------------------------------------

--
-- Table structure for table `cabin_classes`
--

CREATE TABLE `cabin_classes` (
  `id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL COMMENT 'Economy, Business, First',
  `subtitle` varchar(100) DEFAULT NULL COMMENT 'e.g., Classic, Comfort',
  `base_price` decimal(10,2) NOT NULL,
  `baggage_allowance_kg` int(11) DEFAULT 20,
  `cabin_baggage_kg` int(11) DEFAULT 7,
  `priority_boarding` tinyint(1) DEFAULT 0,
  `lounge_access` tinyint(1) DEFAULT 0,
  `extra_legroom` tinyint(1) DEFAULT 0,
  `meal_service` varchar(100) DEFAULT NULL,
  `wifi_included` tinyint(1) DEFAULT 0,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cargo_audit_logs`
--

CREATE TABLE `cargo_audit_logs` (
  `id` int(11) NOT NULL,
  `awb` varchar(20) NOT NULL,
  `from_status` varchar(50) DEFAULT NULL,
  `to_status` varchar(50) DEFAULT NULL,
  `staff_id` int(11) DEFAULT NULL,
  `device_id` varchar(100) DEFAULT NULL,
  `gps_lat` decimal(10,8) DEFAULT NULL,
  `gps_lng` decimal(11,8) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cargo_awb_stock`
--

CREATE TABLE `cargo_awb_stock` (
  `airline_prefix` char(3) NOT NULL,
  `next_serial` int(11) UNSIGNED NOT NULL DEFAULT 1,
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cargo_bookings`
--

CREATE TABLE `cargo_bookings` (
  `id` int(11) NOT NULL,
  `awb_number` varchar(20) NOT NULL,
  `flight_series_id` int(11) DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `origin` varchar(3) NOT NULL,
  `destination` varchar(3) NOT NULL,
  `shipper_name` varchar(255) NOT NULL,
  `shipper_company` varchar(255) DEFAULT NULL,
  `shipper_phone` varchar(50) NOT NULL,
  `shipper_email` varchar(255) DEFAULT NULL,
  `shipper_address` text DEFAULT NULL,
  `consignee_name` varchar(255) NOT NULL,
  `consignee_company` varchar(255) DEFAULT NULL,
  `consignee_phone` varchar(50) NOT NULL,
  `consignee_email` varchar(255) DEFAULT NULL,
  `consignee_address` text DEFAULT NULL,
  `commodity_type` varchar(100) NOT NULL,
  `weight_kg` decimal(10,2) NOT NULL,
  `pieces` int(11) NOT NULL DEFAULT 1,
  `volumetric_weight` decimal(10,2) DEFAULT NULL,
  `chargeable_weight_kg` decimal(10,2) DEFAULT NULL,
  `dimensions_json` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`dimensions_json`)),
  `special_handling_codes` varchar(200) NOT NULL,
  `gross_weight_kg` decimal(11,2) NOT NULL,
  `volume_cbm` decimal(11,3) NOT NULL,
  `declared_value` decimal(15,2) DEFAULT 0.00,
  `total_amount` decimal(15,2) NOT NULL,
  `currency` varchar(3) DEFAULT 'USD',
  `payment_term` varchar(100) NOT NULL,
  `payment_method` varchar(50) DEFAULT 'pending',
  `payment_status` enum('pending','paid','cancelled','refunded') DEFAULT 'pending',
  `amount_paid` decimal(15,2) DEFAULT 0.00,
  `payment_reference` varchar(100) DEFAULT NULL,
  `payment_account` varchar(150) DEFAULT NULL,
  `payment_account_id` int(11) DEFAULT NULL,
  `payment_date` date DEFAULT NULL,
  `payment_confirmed_by` varchar(150) DEFAULT NULL,
  `rate_per_kg` decimal(11,2) NOT NULL,
  `total_charges` decimal(11,2) NOT NULL,
  `booking_phase` enum('hold','confirmed','cancelled') NOT NULL DEFAULT 'hold',
  `status` enum('booked','received','weighed','manifested','in-transit','arrived','delivered') DEFAULT 'booked',
  `notes` text DEFAULT NULL,
  `remarks` varchar(255) DEFAULT NULL,
  `booking_date` date DEFAULT NULL,
  `hold_expires_at` datetime DEFAULT NULL,
  `capacity_snapshot_kg` decimal(10,2) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cargo_capacity_overrides`
--

CREATE TABLE `cargo_capacity_overrides` (
  `id` int(11) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
  `override_date` date NOT NULL,
  `effective_capacity_kg` decimal(10,2) NOT NULL,
  `reason` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_by` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cargo_freight_rates`
--

CREATE TABLE `cargo_freight_rates` (
  `id` int(11) NOT NULL,
  `origin` varchar(10) DEFAULT NULL,
  `destination` varchar(10) DEFAULT NULL,
  `min_weight_kg` decimal(10,2) NOT NULL DEFAULT 0.00,
  `max_weight_kg` decimal(10,2) DEFAULT NULL,
  `rate_per_kg` decimal(10,4) NOT NULL DEFAULT 0.0000,
  `currency` varchar(10) NOT NULL DEFAULT 'USD',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cargo_handling_fees`
--

CREATE TABLE `cargo_handling_fees` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `currency` varchar(10) NOT NULL DEFAULT 'USD',
  `fee_type` varchar(20) NOT NULL DEFAULT 'per_shipment',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cargo_shc_charges`
--

CREATE TABLE `cargo_shc_charges` (
  `id` int(11) NOT NULL,
  `code` varchar(10) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `charge_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `currency` varchar(10) NOT NULL DEFAULT 'USD',
  `charge_type` varchar(20) NOT NULL DEFAULT 'flat',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `cargo_tariffs`
--

CREATE TABLE `cargo_tariffs` (
  `id` int(11) NOT NULL,
  `from_destination_id` int(11) DEFAULT NULL,
  `to_destination_id` int(11) DEFAULT NULL,
  `commodity_type` varchar(100) NOT NULL DEFAULT 'general',
  `min_weight_kg` decimal(10,2) NOT NULL DEFAULT 0.00,
  `max_weight_kg` decimal(10,2) DEFAULT NULL,
  `price_per_kg` decimal(10,2) NOT NULL,
  `min_charge_amount` decimal(10,2) NOT NULL DEFAULT 0.00,
  `currency` char(3) NOT NULL DEFAULT 'USD',
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `effective_from` date DEFAULT NULL,
  `effective_to` date DEFAULT NULL,
  `notes` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `Category`
--

CREATE TABLE `Category` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL,
  `description` text DEFAULT NULL,
  `orderIndex` int(11) DEFAULT 999,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `chart_of_accounts`
--

CREATE TABLE `chart_of_accounts` (
  `id` int(11) NOT NULL,
  `account_name` varchar(100) NOT NULL,
  `account_code` varchar(20) NOT NULL,
  `account_type` int(11) NOT NULL,
  `parent_account_id` int(11) NOT NULL,
  `description` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `is_active` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `chat_messages`
--

CREATE TABLE `chat_messages` (
  `id` int(11) NOT NULL,
  `room_id` int(11) NOT NULL,
  `sender_id` int(11) NOT NULL,
  `isRead` tinyint(1) DEFAULT 0,
  `readAt` timestamp NULL DEFAULT NULL,
  `message` text NOT NULL,
  `messageType` varchar(50) DEFAULT 'text',
  `sent_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `chat_rooms`
--

CREATE TABLE `chat_rooms` (
  `id` int(11) NOT NULL,
  `name` varchar(255) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `is_group` tinyint(1) DEFAULT 0,
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `chat_room_members`
--

CREATE TABLE `chat_room_members` (
  `id` int(11) NOT NULL,
  `room_id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `joined_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `Country`
--

CREATE TABLE `Country` (
  `id` int(11) NOT NULL,
  `name` varchar(191) NOT NULL,
  `status` int(11) DEFAULT 0,
  `tax_percentage` decimal(5,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `crew`
--

CREATE TABLE `crew` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `contact` varchar(50) DEFAULT NULL,
  `role` varchar(100) NOT NULL,
  `nationality` varchar(100) DEFAULT NULL,
  `id_number` varchar(50) DEFAULT NULL,
  `license_number` varchar(50) DEFAULT NULL,
  `license_issue_date` date DEFAULT NULL,
  `medical_class` varchar(20) DEFAULT NULL,
  `medical_date` date DEFAULT NULL,
  `fixed_wing_training_date` date DEFAULT NULL,
  `rotorcraft_asel` date DEFAULT NULL,
  `rotorcraft_amel` date DEFAULT NULL,
  `rotorcraft_ases` date DEFAULT NULL,
  `rotorcraft_ames` date DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `crew_assignments`
--

CREATE TABLE `crew_assignments` (
  `id` int(11) NOT NULL,
  `flight_id` int(11) NOT NULL,
  `crew_id` int(11) NOT NULL,
  `role` varchar(100) DEFAULT NULL,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `currencies`
--

CREATE TABLE `currencies` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `country` varchar(100) NOT NULL,
  `symbol` varchar(10) NOT NULL,
  `code` varchar(10) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  `is_default` tinyint(4) NOT NULL DEFAULT 0,
  `exchange_rate` decimal(15,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `delete_acc`
--

CREATE TABLE `delete_acc` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `status` int(11) NOT NULL,
  `is_true` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `departments`
--

CREATE TABLE `departments` (
  `id` int(11) NOT NULL,
  `name` varchar(50) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `destinations`
--

CREATE TABLE `destinations` (
  `id` int(11) NOT NULL,
  `code` varchar(50) NOT NULL,
  `name` varchar(255) NOT NULL,
  `country_id` int(11) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `latitude` decimal(10,7) DEFAULT NULL,
  `timezone` varchar(100) DEFAULT NULL,
  `status` varchar(50) NOT NULL DEFAULT 'active',
  `is_popular` tinyint(1) NOT NULL DEFAULT 0,
  `father_code` varchar(50) DEFAULT NULL,
  `destination` varchar(255) DEFAULT NULL,
  `image_url` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `destination_type` varchar(20) NOT NULL DEFAULT 'domestic',
  `icao_code` varchar(10) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `device_tokens`
--

CREATE TABLE `device_tokens` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `device_token` varchar(255) NOT NULL,
  `platform` enum('ios','android') NOT NULL DEFAULT 'ios',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `exception_types`
--

CREATE TABLE `exception_types` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `notification` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `exchange_rates`
--

CREATE TABLE `exchange_rates` (
  `id` int(11) NOT NULL,
  `currency_code` varchar(3) NOT NULL,
  `rate` decimal(10,6) NOT NULL COMMENT 'Exchange rate relative to EUR (Fixer Base)',
  `last_updated` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `expenses`
--

CREATE TABLE `expenses` (
  `id` int(11) NOT NULL,
  `journal_entry_id` int(11) NOT NULL,
  `supplier_id` int(11) DEFAULT NULL,
  `expense_type_id` int(11) DEFAULT NULL,
  `amount_paid` decimal(11,2) NOT NULL,
  `balance` decimal(11,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `expense_categories`
--

CREATE TABLE `expense_categories` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `description` text DEFAULT NULL,
  `is_active` tinyint(4) DEFAULT 1,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `expense_types`
--

CREATE TABLE `expense_types` (
  `id` int(11) NOT NULL,
  `name` varchar(100) NOT NULL,
  `category_id` int(11) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `is_active` tinyint(4) DEFAULT 1,
  `created_at` datetime DEFAULT current_timestamp(),
  `updated_at` datetime DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `experiences`
--

CREATE TABLE `experiences` (
  `id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `subtitle` varchar(255) DEFAULT NULL,
  `icon` varchar(50) DEFAULT NULL,
  `color_hex` varchar(10) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `fare_history`
--

CREATE TABLE `fare_history` (
  `id` int(11) NOT NULL,
  `route_id` int(11) NOT NULL,
  `adult_fare` decimal(10,2) DEFAULT NULL,
  `child_fare` decimal(10,2) DEFAULT NULL,
  `infant_fare` decimal(10,2) DEFAULT NULL,
  `changed_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `fare_valid_from` date DEFAULT NULL,
  `fare_valid_to` date DEFAULT NULL,
  `adult_return_fare` decimal(10,2) DEFAULT NULL,
  `child_return_fare` decimal(10,2) DEFAULT NULL,
  `infant_return_fare` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `flights`
--

CREATE TABLE `flights` (
  `id` int(11) NOT NULL,
  `series_id` int(11) NOT NULL,
  `aircraft_id` int(11) DEFAULT NULL,
  `aircraft_capacity` int(11) DEFAULT NULL,
  `flight_no` varchar(50) NOT NULL,
  `flight_date` date NOT NULL,
  `std` time DEFAULT NULL,
  `sta` time DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'scheduled',
  `is_extra` tinyint(1) NOT NULL DEFAULT 0,
  `notes` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `flight_crew`
--

CREATE TABLE `flight_crew` (
  `id` int(11) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
  `crew_id` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `flight_exceptions`
--

CREATE TABLE `flight_exceptions` (
  `id` int(11) NOT NULL,
  `flight_id` int(11) NOT NULL,
  `exception_type` int(11) NOT NULL,
  `reason` text DEFAULT NULL,
  `old_value` varchar(255) DEFAULT NULL,
  `new_value` varchar(255) DEFAULT NULL,
  `created_by` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `flight_routes`
--

CREATE TABLE `flight_routes` (
  `id` int(11) NOT NULL,
  `from_destination_id` int(11) NOT NULL,
  `to_destination_id` int(11) NOT NULL,
  `adult_fare` decimal(10,2) DEFAULT NULL,
  `child_fare` decimal(10,2) DEFAULT NULL,
  `infant_fare` decimal(10,2) DEFAULT NULL,
  `status` varchar(20) NOT NULL DEFAULT 'active',
  `created_at` datetime(6) NOT NULL DEFAULT current_timestamp(6),
  `updated_at` datetime(6) NOT NULL DEFAULT current_timestamp(6) ON UPDATE current_timestamp(6),
  `route_type` varchar(20) NOT NULL DEFAULT 'domestic',
  `fare_valid_from` date DEFAULT NULL,
  `fare_valid_to` date DEFAULT NULL,
  `adult_return_fare` decimal(10,2) DEFAULT NULL,
  `child_return_fare` decimal(10,2) DEFAULT NULL,
  `infant_return_fare` decimal(10,2) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `flight_series`
--

CREATE TABLE `flight_series` (
  `id` int(11) NOT NULL,
  `flt` varchar(50) NOT NULL,
  `aircraft_id` int(11) DEFAULT NULL,
  `flight_type` varchar(50) NOT NULL,
  `start_date` date NOT NULL,
  `end_date` date NOT NULL,
  `std` time DEFAULT NULL,
  `sta` time DEFAULT NULL,
  `number_of_seats` int(11) DEFAULT NULL,
  `is_recurring` tinyint(1) NOT NULL DEFAULT 0,
  `days_of_week` varchar(20) DEFAULT NULL,
  `recurring_schedule` text DEFAULT NULL,
  `from_destination_id` int(11) DEFAULT NULL,
  `from_terminal` varchar(100) DEFAULT NULL,
  `to_terminal` varchar(100) DEFAULT NULL,
  `via_destination_id` int(11) DEFAULT NULL,
  `via_std` time DEFAULT NULL,
  `via_sta` time DEFAULT NULL,
  `to_destination_id` int(11) DEFAULT NULL,
  `adult_fare` decimal(10,2) DEFAULT NULL,
  `child_fare` decimal(10,2) DEFAULT NULL,
  `infant_fare` decimal(10,2) DEFAULT NULL,
  `adult_return_fare` decimal(10,2) DEFAULT NULL,
  `child_return_fare` decimal(10,2) DEFAULT NULL,
  `infant_return_fare` decimal(10,2) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` varchar(50) DEFAULT 'Scheduled',
  `actual_std` time DEFAULT NULL,
  `actual_sta` time DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `float_requests`
--

CREATE TABLE `float_requests` (
  `id` int(11) NOT NULL,
  `requester_type` enum('agent','agency') NOT NULL,
  `requester_id` int(11) NOT NULL COMMENT 'agents.id or agencies.id',
  `agency_id` int(11) DEFAULT NULL COMMENT 'agencies.id; required when requester_type = agent',
  `amount` decimal(15,2) NOT NULL,
  `currency` char(3) NOT NULL DEFAULT 'KES',
  `status` enum('pending','approved','rejected','cancelled') NOT NULL DEFAULT 'pending',
  `payment_method` varchar(50) DEFAULT NULL COMMENT 'E.g. Bank Transfer, M-Pesa',
  `payment_reference` varchar(100) DEFAULT NULL,
  `proof_url` varchar(512) DEFAULT NULL COMMENT 'URL to uploaded bank slip / receipt',
  `request_notes` text DEFAULT NULL,
  `reviewed_by` int(11) DEFAULT NULL COMMENT 'Agency user or admin who actioned this',
  `review_notes` text DEFAULT NULL,
  `reviewed_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Float top-up requests from agents/agencies';

-- --------------------------------------------------------

--
-- Table structure for table `fueling`
--

CREATE TABLE `fueling` (
  `id` int(11) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `fuel_quantity` decimal(10,2) NOT NULL,
  `fuel_slip_number` varchar(100) NOT NULL,
  `price_per_liter` decimal(10,2) NOT NULL,
  `location` varchar(255) NOT NULL,
  `additional_fees` decimal(10,2) DEFAULT 0.00,
  `additional_fees_explanation` varchar(255) NOT NULL,
  `total_amount` decimal(15,2) NOT NULL,
  `tax` decimal(11,2) NOT NULL,
  `fueling_date` date NOT NULL,
  `journal_entry_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `hotels`
--

CREATE TABLE `hotels` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `location` varchar(255) NOT NULL,
  `description` text DEFAULT NULL,
  `amenities` text DEFAULT NULL,
  `image_url` varchar(255) DEFAULT NULL,
  `price_per_night` decimal(10,2) DEFAULT NULL,
  `rating` decimal(2,1) DEFAULT NULL,
  `review_count` int(11) NOT NULL DEFAULT 0,
  `booking_url` varchar(255) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `iata_codes`
--

CREATE TABLE `iata_codes` (
  `id` int(11) NOT NULL,
  `code` varchar(3) NOT NULL,
  `icao` varchar(4) DEFAULT NULL,
  `airport` varchar(255) NOT NULL,
  `city` varchar(100) DEFAULT NULL,
  `country_code` varchar(2) NOT NULL,
  `region_name` varchar(100) DEFAULT NULL,
  `latitude` decimal(10,7) DEFAULT NULL,
  `longitude` decimal(10,7) DEFAULT NULL,
  `status` varchar(50) DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `journal_entries`
--

CREATE TABLE `journal_entries` (
  `id` int(11) NOT NULL,
  `entry_number` varchar(20) NOT NULL,
  `entry_date` date NOT NULL,
  `reference` varchar(100) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `total_debit` decimal(15,2) DEFAULT 0.00,
  `total_credit` decimal(15,2) DEFAULT 0.00,
  `status` enum('draft','posted','cancelled') DEFAULT 'draft',
  `created_by` int(11) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `journal_entry_lines`
--

CREATE TABLE `journal_entry_lines` (
  `id` int(11) NOT NULL,
  `journal_entry_id` int(11) NOT NULL,
  `account_id` int(11) NOT NULL,
  `debit_amount` decimal(15,2) DEFAULT 0.00,
  `credit_amount` decimal(15,2) DEFAULT 0.00,
  `description` text DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `loyalty_points_history`
--

CREATE TABLE `loyalty_points_history` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `booking_id` int(11) DEFAULT NULL,
  `points` int(11) NOT NULL,
  `transaction_type` enum('EARN','REDEEM','ADJUSTMENT') NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `loyalty_tiers`
--

CREATE TABLE `loyalty_tiers` (
  `id` int(11) NOT NULL,
  `name` enum('BRONZE','SILVER','GOLD','PLATINUM') NOT NULL,
  `min_points` int(11) NOT NULL,
  `description` text DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `luggage`
--

CREATE TABLE `luggage` (
  `id` int(11) NOT NULL,
  `passenger_id` int(11) NOT NULL,
  `flight_series_id` int(11) DEFAULT NULL,
  `flight_id` int(11) DEFAULT NULL,
  `booking_id` int(11) DEFAULT NULL,
  `booking_reference` varchar(50) DEFAULT NULL,
  `staff_id` int(11) DEFAULT NULL,
  `tag_number` varchar(50) DEFAULT NULL,
  `weight` decimal(8,2) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notices`
--

CREATE TABLE `notices` (
  `id` int(11) NOT NULL,
  `title` text NOT NULL,
  `content` text NOT NULL,
  `country_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `status` tinyint(3) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `notifications`
--

CREATE TABLE `notifications` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `booking_id` int(11) DEFAULT NULL,
  `type` enum('booking_confirmed','payment_reminder','checkin_available','gate_change','delay','cancellation','general') NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `is_read` tinyint(1) DEFAULT 0,
  `sent_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `offers`
--

CREATE TABLE `offers` (
  `id` int(11) NOT NULL,
  `title` varchar(255) NOT NULL,
  `description` text NOT NULL,
  `image_url` varchar(255) DEFAULT NULL,
  `promo_code` varchar(50) DEFAULT NULL,
  `expiry_date` date DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3 COLLATE=utf8mb3_general_ci;

-- --------------------------------------------------------

--
-- Table structure for table `passengers`
--

CREATE TABLE `passengers` (
  `id` int(11) NOT NULL,
  `pnr` varchar(20) NOT NULL,
  `name` varchar(255) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `contact` varchar(50) DEFAULT NULL,
  `nationality` varchar(100) DEFAULT NULL,
  `id_type` varchar(30) DEFAULT NULL,
  `identification` varchar(100) DEFAULT NULL,
  `age` int(11) DEFAULT NULL,
  `title` varchar(20) DEFAULT NULL,
  `booking_status` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `passenger_disruptions`
--

CREATE TABLE `passenger_disruptions` (
  `id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `flight_id` int(11) NOT NULL,
  `disruption_type` varchar(100) NOT NULL,
  `action_taken` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `password_resets`
--

CREATE TABLE `password_resets` (
  `id` int(11) NOT NULL,
  `email` varchar(255) NOT NULL,
  `token` varchar(255) NOT NULL,
  `used` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL,
  `expires_at` datetime NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `payment_transactions`
--

CREATE TABLE `payment_transactions` (
  `id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `amount` decimal(10,2) NOT NULL,
  `currency` varchar(3) DEFAULT 'USD',
  `payment_method` varchar(50) NOT NULL COMMENT 'M-Pesa, Card, etc',
  `payment_reference` varchar(100) DEFAULT NULL,
  `transaction_id` varchar(100) DEFAULT NULL COMMENT 'External payment gateway ID',
  `status` enum('pending','completed','failed','refunded') DEFAULT 'pending',
  `payment_date` datetime DEFAULT NULL,
  `metadata` text DEFAULT NULL COMMENT 'JSON data from payment gateway',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `payroll`
--

CREATE TABLE `payroll` (
  `id` int(11) NOT NULL,
  `journal_entry_id` int(11) NOT NULL,
  `staff_id` int(11) NOT NULL,
  `payroll_date` date NOT NULL,
  `amount` decimal(15,2) NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `reference` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `portal_login_activity`
--

CREATE TABLE `portal_login_activity` (
  `id` int(11) NOT NULL,
  `entity_type` enum('agency','agent') NOT NULL,
  `entity_id` int(11) NOT NULL,
  `event` enum('login','logout','failed_login','password_reset','token_refresh') NOT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text DEFAULT NULL,
  `location` varchar(255) DEFAULT NULL COMMENT 'Reverse-geocoded city/country if available',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Full audit trail of portal auth events';

-- --------------------------------------------------------

--
-- Table structure for table `portal_notifications`
--

CREATE TABLE `portal_notifications` (
  `id` int(11) NOT NULL,
  `recipient_type` enum('agent','agency') NOT NULL,
  `recipient_id` int(11) NOT NULL,
  `type` enum('booking_success','ticket_issued','refund_completed','amendment_processed','low_float_alert','topup_approved','topup_rejected','booking_cancelled','booking_expired','system_notice') NOT NULL,
  `title` varchar(255) NOT NULL,
  `message` text NOT NULL,
  `booking_id` int(11) DEFAULT NULL,
  `float_request_id` int(11) DEFAULT NULL,
  `channel` enum('in_app','email','both') NOT NULL DEFAULT 'both',
  `is_read` tinyint(1) NOT NULL DEFAULT 0,
  `read_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Portal notifications — separate from customer-facing notifications';

-- --------------------------------------------------------

--
-- Table structure for table `portal_sessions`
--

CREATE TABLE `portal_sessions` (
  `id` int(11) NOT NULL,
  `entity_type` enum('agency','agent') NOT NULL,
  `entity_id` int(11) NOT NULL COMMENT 'agencies.id or agents.id',
  `refresh_token_hash` varchar(255) NOT NULL COMMENT 'bcrypt hash of the refresh token',
  `ip_address` varchar(45) DEFAULT NULL,
  `user_agent` text DEFAULT NULL,
  `is_valid` tinyint(1) NOT NULL DEFAULT 1,
  `expires_at` datetime NOT NULL,
  `revoked_at` datetime DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='JWT refresh token store for portal sessions';

-- --------------------------------------------------------

--
-- Table structure for table `push_subscriptions`
--

CREATE TABLE `push_subscriptions` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `provider` varchar(32) NOT NULL DEFAULT 'onesignal',
  `platform` enum('android','ios','web') NOT NULL DEFAULT 'android',
  `subscription_id` varchar(191) NOT NULL,
  `external_user_id` varchar(191) DEFAULT NULL,
  `status` enum('active','inactive') NOT NULL DEFAULT 'active',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `saved_passenger_profiles`
--

CREATE TABLE `saved_passenger_profiles` (
  `id` int(11) NOT NULL,
  `owner_type` enum('agent','agency') NOT NULL,
  `owner_id` int(11) NOT NULL,
  `title` varchar(10) DEFAULT NULL COMMENT 'Mr / Mrs / Ms / Dr etc.',
  `first_name` varchar(100) NOT NULL,
  `last_name` varchar(100) NOT NULL,
  `email` varchar(255) DEFAULT NULL,
  `phone` varchar(50) DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `nationality` varchar(100) DEFAULT NULL,
  `identification_type` enum('passport','national_id','other') DEFAULT 'passport',
  `identification_number` varchar(100) DEFAULT NULL,
  `passport_expiry_date` date DEFAULT NULL,
  `frequent_flyer_number` varchar(50) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Reusable passenger profiles per agent/agency';

-- --------------------------------------------------------

--
-- Table structure for table `seat_reservations`
--

CREATE TABLE `seat_reservations` (
  `id` int(11) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
  `flight_id` int(11) DEFAULT NULL,
  `number_of_seats` int(11) NOT NULL DEFAULT 1,
  `passenger_id` int(11) DEFAULT NULL,
  `passenger_name` varchar(255) NOT NULL,
  `passenger_title` varchar(20) DEFAULT NULL,
  `passenger_email` varchar(255) DEFAULT NULL,
  `passenger_phone` varchar(50) DEFAULT NULL,
  `booking_reference` varchar(50) NOT NULL,
  `status` varchar(50) NOT NULL DEFAULT 'reserved',
  `reservation_date` date NOT NULL,
  `notes` text DEFAULT NULL,
  `trip_type` varchar(20) NOT NULL DEFAULT 'one_way',
  `return_flight_series_id` int(11) DEFAULT NULL,
  `return_date` date DEFAULT NULL,
  `linked_reservation_id` int(11) DEFAULT NULL,
  `fare_amount` decimal(10,2) DEFAULT NULL,
  `payment_status` varchar(20) NOT NULL DEFAULT 'unpaid',
  `amount_paid` decimal(10,2) NOT NULL DEFAULT 0.00,
  `agent_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `country_id` int(11) DEFAULT NULL,
  `id_type` varchar(30) DEFAULT NULL,
  `id_number` varchar(100) DEFAULT NULL,
  `id_expiry` date DEFAULT NULL,
  `id_issued_by` varchar(100) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `settings`
--

CREATE TABLE `settings` (
  `id` int(11) NOT NULL,
  `setting_key` varchar(64) NOT NULL,
  `setting_value` text DEFAULT NULL,
  `group_name` varchar(32) DEFAULT 'general',
  `description` varchar(255) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Table structure for table `staff`
--

CREATE TABLE `staff` (
  `id` int(11) NOT NULL,
  `name` varchar(255) NOT NULL,
  `photo_url` varchar(255) NOT NULL,
  `empl_no` varchar(50) NOT NULL,
  `id_no` varchar(50) NOT NULL,
  `role` varchar(255) NOT NULL,
  `designation` varchar(255) DEFAULT NULL,
  `phone_number` varchar(50) DEFAULT NULL,
  `password` varchar(255) NOT NULL,
  `department` varchar(100) DEFAULT NULL,
  `department_id` int(11) DEFAULT NULL,
  `manager_id` int(11) DEFAULT NULL,
  `business_email` varchar(255) DEFAULT NULL,
  `department_email` varchar(255) DEFAULT NULL,
  `salary` decimal(11,2) DEFAULT NULL,
  `employment_type` varchar(100) NOT NULL,
  `gender` enum('Male','Female','Other') NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `is_active` int(3) NOT NULL,
  `avatar_url` varchar(200) NOT NULL,
  `status` int(11) NOT NULL,
  `my_password` varchar(255) NOT NULL,
  `wifi_ip` varchar(100) NOT NULL,
  `shift` int(11) NOT NULL,
  `offer_date` date DEFAULT NULL,
  `start_date` date DEFAULT NULL,
  `date_of_birth` date DEFAULT NULL,
  `marital_status` enum('Single','Married','Divorced','Widowed') DEFAULT NULL,
  `nationality` varchar(100) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `nhif_number` varchar(50) DEFAULT NULL,
  `nssf_number` varchar(50) DEFAULT NULL,
  `kra_pin` varchar(50) DEFAULT NULL,
  `passport_number` varchar(50) DEFAULT NULL,
  `bank_name` varchar(255) DEFAULT NULL,
  `bank_branch` varchar(255) DEFAULT NULL,
  `account_number` varchar(50) DEFAULT NULL,
  `account_name` varchar(255) DEFAULT NULL,
  `swift_code` varchar(50) DEFAULT NULL,
  `benefits` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`benefits`))
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `suppliers`
--

CREATE TABLE `suppliers` (
  `id` int(11) NOT NULL,
  `supplier_code` varchar(20) NOT NULL,
  `company_name` varchar(100) NOT NULL,
  `contact_person` varchar(100) DEFAULT NULL,
  `email` varchar(100) DEFAULT NULL,
  `phone` varchar(20) DEFAULT NULL,
  `address` text DEFAULT NULL,
  `tax_id` varchar(50) DEFAULT NULL,
  `payment_terms` int(11) DEFAULT 30,
  `credit_limit` decimal(15,2) DEFAULT 0.00,
  `is_active` tinyint(1) DEFAULT 1,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `supplier_ledger`
--

CREATE TABLE `supplier_ledger` (
  `id` int(11) NOT NULL,
  `supplier_id` int(11) NOT NULL,
  `date` datetime NOT NULL,
  `description` varchar(255) DEFAULT NULL,
  `reference_type` varchar(50) DEFAULT NULL,
  `reference_id` int(11) DEFAULT NULL,
  `debit` decimal(15,2) DEFAULT 0.00,
  `credit` decimal(15,2) DEFAULT 0.00,
  `running_balance` decimal(15,2) DEFAULT 0.00,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

-- --------------------------------------------------------

--
-- Table structure for table `ticket_exports`
--

CREATE TABLE `ticket_exports` (
  `id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `exported_by_type` enum('agent','agency','system') NOT NULL DEFAULT 'system',
  `exported_by_id` int(11) DEFAULT NULL,
  `export_type` enum('pdf','email','both') NOT NULL DEFAULT 'pdf',
  `file_url` varchar(512) DEFAULT NULL COMMENT 'Storage URL of generated PDF',
  `email_to` varchar(255) DEFAULT NULL,
  `email_sent_at` datetime DEFAULT NULL,
  `email_status` enum('pending','sent','failed') DEFAULT NULL,
  `email_error` text DEFAULT NULL COMMENT 'Error message if email_status = failed',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='Tracks every ticket PDF generation and email delivery';

--
-- Indexes for dumped tables
--

--
-- Indexes for table `accounts`
--
ALTER TABLE `accounts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`);

--
-- Indexes for table `account_category`
--
ALTER TABLE `account_category`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `account_deletion_requests`
--
ALTER TABLE `account_deletion_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

--
-- Indexes for table `account_ledger`
--
ALTER TABLE `account_ledger`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_account_id` (`account_id`),
  ADD KEY `idx_transaction_date` (`transaction_date`);

--
-- Indexes for table `account_types`
--
ALTER TABLE `account_types`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `agencies`
--
ALTER TABLE `agencies`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_name` (`name`),
  ADD KEY `idx_country` (`country`),
  ADD KEY `idx_city` (`city`),
  ADD KEY `idx_default_currency` (`default_currency`),
  ADD KEY `idx_credit_days` (`credit_days`);

--
-- Indexes for table `agency_deposits`
--
ALTER TABLE `agency_deposits`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_agency_id` (`agency_id`),
  ADD KEY `idx_account_id` (`account_id`),
  ADD KEY `idx_date_paid` (`date_paid`),
  ADD KEY `idx_reference` (`reference`);

--
-- Indexes for table `agency_ledger`
--
ALTER TABLE `agency_ledger`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_agency_id` (`agency_id`),
  ADD KEY `idx_transaction_date` (`transaction_date`),
  ADD KEY `idx_agency_ledger_type` (`transaction_type`),
  ADD KEY `idx_agency_ledger_booking` (`booking_id`);

--
-- Indexes for table `agents`
--
ALTER TABLE `agents`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_agency_id` (`agency_id`),
  ADD KEY `idx_name` (`name`),
  ADD KEY `idx_email` (`email`);

--
-- Indexes for table `agent_commissions`
--
ALTER TABLE `agent_commissions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_commission_booking` (`booking_id`),
  ADD KEY `idx_ac_agent` (`agent_id`),
  ADD KEY `idx_ac_agency` (`agency_id`);

--
-- Indexes for table `aircrafts`
--
ALTER TABLE `aircrafts`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `registration` (`registration`),
  ADD KEY `idx_registration` (`registration`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_created_by` (`created_by`),
  ADD KEY `idx_category_id` (`category_id`);

--
-- Indexes for table `airline_users`
--
ALTER TABLE `airline_users`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `phone_number` (`phone_number`),
  ADD UNIQUE KEY `email` (`email`),
  ADD UNIQUE KEY `frequent_flyer_number` (`frequent_flyer_number`),
  ADD KEY `idx_phone` (`phone_number`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_ff_number` (`frequent_flyer_number`),
  ADD KEY `idx_member_club` (`member_club`);

--
-- Indexes for table `bookings`
--
ALTER TABLE `bookings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `booking_reference` (`booking_reference`),
  ADD KEY `idx_booking_reference` (`booking_reference`),
  ADD KEY `idx_flight_series_id` (`flight_series_id`),
  ADD KEY `idx_passenger_id` (`passenger_id`),
  ADD KEY `idx_booking_date` (`booking_date`),
  ADD KEY `idx_payment_status` (`payment_status`),
  ADD KEY `idx_user_id` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_booking_reservation_expires_at` (`reservation_expires_at`),
  ADD KEY `idx_booking_expired_at` (`expired_at`),
  ADD KEY `idx_bookings_agent` (`agent_id`),
  ADD KEY `idx_bookings_agency` (`agency_id`),
  ADD KEY `idx_bookings_source` (`source`),
  ADD KEY `fk_bookings_flight` (`flight_id`);

--
-- Indexes for table `booking_amendments`
--
ALTER TABLE `booking_amendments`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_ba_booking` (`booking_id`),
  ADD KEY `idx_ba_status` (`status`);

--
-- Indexes for table `booking_passengers`
--
ALTER TABLE `booking_passengers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `UQ_bp_booking_pax_leg` (`booking_id`,`passenger_id`,`leg`),
  ADD UNIQUE KEY `unique_booking_passenger` (`booking_id`,`passenger_id`,`leg`),
  ADD UNIQUE KEY `idx_ticket_number` (`ticket_number`),
  ADD KEY `passenger_id` (`passenger_id`),
  ADD KEY `fk_bp_flight` (`flight_id`);

--
-- Indexes for table `booking_status_history`
--
ALTER TABLE `booking_status_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_bsh_booking` (`booking_id`),
  ADD KEY `idx_bsh_created` (`created_at`);

--
-- Indexes for table `cabin_classes`
--
ALTER TABLE `cabin_classes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_name` (`name`);

--
-- Indexes for table `cargo_audit_logs`
--
ALTER TABLE `cargo_audit_logs`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cargo_awb_stock`
--
ALTER TABLE `cargo_awb_stock`
  ADD PRIMARY KEY (`airline_prefix`);

--
-- Indexes for table `cargo_bookings`
--
ALTER TABLE `cargo_bookings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `awb_number` (`awb_number`),
  ADD KEY `idx_awb_number` (`awb_number`),
  ADD KEY `idx_cargo_booking_date` (`booking_date`),
  ADD KEY `idx_cargo_booking_phase` (`booking_phase`),
  ADD KEY `idx_cargo_hold_expires_at` (`hold_expires_at`),
  ADD KEY `idx_cargo_flight_date_phase` (`flight_series_id`,`booking_date`,`booking_phase`);

--
-- Indexes for table `cargo_capacity_overrides`
--
ALTER TABLE `cargo_capacity_overrides`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_cargo_capacity_override_flight_date` (`flight_series_id`,`override_date`),
  ADD KEY `idx_cargo_capacity_override_date` (`override_date`),
  ADD KEY `idx_cargo_capacity_override_active` (`is_active`);

--
-- Indexes for table `cargo_freight_rates`
--
ALTER TABLE `cargo_freight_rates`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cargo_handling_fees`
--
ALTER TABLE `cargo_handling_fees`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `cargo_shc_charges`
--
ALTER TABLE `cargo_shc_charges`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_code` (`code`);

--
-- Indexes for table `cargo_tariffs`
--
ALTER TABLE `cargo_tariffs`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_cargo_tariff_route` (`from_destination_id`,`to_destination_id`),
  ADD KEY `idx_cargo_tariff_commodity` (`commodity_type`),
  ADD KEY `idx_cargo_tariff_active` (`is_active`),
  ADD KEY `idx_cargo_tariff_effective` (`effective_from`,`effective_to`),
  ADD KEY `fk_cargo_tariff_to_destination` (`to_destination_id`);

--
-- Indexes for table `Category`
--
ALTER TABLE `Category`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_category_order` (`orderIndex`,`name`),
  ADD KEY `idx_category_active` (`is_active`);

--
-- Indexes for table `chart_of_accounts`
--
ALTER TABLE `chart_of_accounts`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `chat_messages`
--
ALTER TABLE `chat_messages`
  ADD PRIMARY KEY (`id`),
  ADD KEY `room_id` (`room_id`),
  ADD KEY `sender_id` (`sender_id`);

--
-- Indexes for table `chat_rooms`
--
ALTER TABLE `chat_rooms`
  ADD PRIMARY KEY (`id`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `chat_room_members`
--
ALTER TABLE `chat_room_members`
  ADD PRIMARY KEY (`id`),
  ADD KEY `room_id` (`room_id`),
  ADD KEY `staff_id` (`staff_id`);

--
-- Indexes for table `Country`
--
ALTER TABLE `Country`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `crew`
--
ALTER TABLE `crew`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_name` (`name`),
  ADD KEY `idx_role` (`role`),
  ADD KEY `idx_license_number` (`license_number`);

--
-- Indexes for table `crew_assignments`
--
ALTER TABLE `crew_assignments`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uq_flight_crew` (`flight_id`,`crew_id`),
  ADD KEY `fk_ca_crew` (`crew_id`);

--
-- Indexes for table `currencies`
--
ALTER TABLE `currencies`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `delete_acc`
--
ALTER TABLE `delete_acc`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `departments`
--
ALTER TABLE `departments`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `destinations`
--
ALTER TABLE `destinations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`),
  ADD KEY `idx_code` (`code`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_country_id` (`country_id`),
  ADD KEY `idx_father_code` (`father_code`);

--
-- Indexes for table `device_tokens`
--
ALTER TABLE `device_tokens`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_user_device` (`user_id`,`device_token`);

--
-- Indexes for table `exception_types`
--
ALTER TABLE `exception_types`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `exchange_rates`
--
ALTER TABLE `exchange_rates`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `currency_code` (`currency_code`);

--
-- Indexes for table `expenses`
--
ALTER TABLE `expenses`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_journal_entry_id` (`journal_entry_id`),
  ADD KEY `idx_supplier_id` (`supplier_id`);

--
-- Indexes for table `expense_categories`
--
ALTER TABLE `expense_categories`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `expense_types`
--
ALTER TABLE `expense_types`
  ADD PRIMARY KEY (`id`),
  ADD KEY `category_id` (`category_id`);

--
-- Indexes for table `experiences`
--
ALTER TABLE `experiences`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `fare_history`
--
ALTER TABLE `fare_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `FK_fare_history_route` (`route_id`);

--
-- Indexes for table `flights`
--
ALTER TABLE `flights`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_flights_aircraft` (`aircraft_id`),
  ADD KEY `idx_flights_series_id` (`series_id`);

--
-- Indexes for table `flight_crew`
--
ALTER TABLE `flight_crew`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_flight_crew` (`flight_series_id`,`crew_id`),
  ADD KEY `idx_flight_series_id` (`flight_series_id`),
  ADD KEY `idx_crew_id` (`crew_id`);

--
-- Indexes for table `flight_exceptions`
--
ALTER TABLE `flight_exceptions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_fe_flight` (`flight_id`),
  ADD KEY `fk_fe_type` (`exception_type`);

--
-- Indexes for table `flight_routes`
--
ALTER TABLE `flight_routes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `FK_route_from` (`from_destination_id`),
  ADD KEY `FK_route_to` (`to_destination_id`);

--
-- Indexes for table `flight_series`
--
ALTER TABLE `flight_series`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_flt` (`flt`),
  ADD KEY `idx_aircraft_id` (`aircraft_id`),
  ADD KEY `idx_flight_type` (`flight_type`),
  ADD KEY `idx_start_date` (`start_date`),
  ADD KEY `idx_end_date` (`end_date`),
  ADD KEY `idx_from_destination_id` (`from_destination_id`),
  ADD KEY `idx_via_destination_id` (`via_destination_id`),
  ADD KEY `idx_to_destination_id` (`to_destination_id`);

--
-- Indexes for table `float_requests`
--
ALTER TABLE `float_requests`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_fr_requester` (`requester_type`,`requester_id`),
  ADD KEY `idx_fr_agency` (`agency_id`),
  ADD KEY `idx_fr_status` (`status`);

--
-- Indexes for table `fueling`
--
ALTER TABLE `fueling`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_flight_series_id` (`flight_series_id`),
  ADD KEY `idx_supplier_id` (`supplier_id`),
  ADD KEY `idx_fueling_date` (`fueling_date`),
  ADD KEY `idx_fuel_slip_number` (`fuel_slip_number`),
  ADD KEY `idx_journal_entry_id` (`journal_entry_id`);

--
-- Indexes for table `hotels`
--
ALTER TABLE `hotels`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `iata_codes`
--
ALTER TABLE `iata_codes`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `code` (`code`),
  ADD KEY `idx_code` (`code`),
  ADD KEY `idx_country` (`country_code`),
  ADD KEY `idx_airport` (`airport`);

--
-- Indexes for table `journal_entries`
--
ALTER TABLE `journal_entries`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `entry_number` (`entry_number`),
  ADD KEY `created_by` (`created_by`);

--
-- Indexes for table `journal_entry_lines`
--
ALTER TABLE `journal_entry_lines`
  ADD PRIMARY KEY (`id`),
  ADD KEY `journal_entry_id` (`journal_entry_id`),
  ADD KEY `account_id` (`account_id`);

--
-- Indexes for table `loyalty_points_history`
--
ALTER TABLE `loyalty_points_history`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_user_loyalty` (`user_id`);

--
-- Indexes for table `loyalty_tiers`
--
ALTER TABLE `loyalty_tiers`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `luggage`
--
ALTER TABLE `luggage`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `idx_unique_tag_number` (`tag_number`),
  ADD KEY `idx_passenger_id` (`passenger_id`),
  ADD KEY `idx_flight_series_id` (`flight_series_id`),
  ADD KEY `idx_booking_id` (`booking_id`);

--
-- Indexes for table `notices`
--
ALTER TABLE `notices`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `notifications`
--
ALTER TABLE `notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `booking_id` (`booking_id`),
  ADD KEY `idx_user` (`user_id`),
  ADD KEY `idx_is_read` (`is_read`),
  ADD KEY `idx_type` (`type`),
  ADD KEY `idx_notifications_user_unread` (`user_id`,`is_read`),
  ADD KEY `idx_notifications_user_read_created` (`user_id`,`is_read`,`created_at`);

--
-- Indexes for table `offers`
--
ALTER TABLE `offers`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `passengers`
--
ALTER TABLE `passengers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `pnr` (`pnr`),
  ADD KEY `idx_pnr` (`pnr`),
  ADD KEY `idx_email` (`email`),
  ADD KEY `idx_name` (`name`),
  ADD KEY `idx_identification` (`identification`);

--
-- Indexes for table `passenger_disruptions`
--
ALTER TABLE `passenger_disruptions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_pd_booking` (`booking_id`),
  ADD KEY `fk_pd_flight` (`flight_id`);

--
-- Indexes for table `password_resets`
--
ALTER TABLE `password_resets`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `token` (`token`),
  ADD KEY `email` (`email`);

--
-- Indexes for table `payment_transactions`
--
ALTER TABLE `payment_transactions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_payment_gateway_method_ref` (`payment_method`,`transaction_id`),
  ADD KEY `idx_booking` (`booking_id`),
  ADD KEY `idx_user` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_reference` (`payment_reference`),
  ADD KEY `idx_transaction_id` (`transaction_id`);

--
-- Indexes for table `payroll`
--
ALTER TABLE `payroll`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_journal_entry_id` (`journal_entry_id`),
  ADD KEY `idx_staff_id` (`staff_id`),
  ADD KEY `idx_payroll_date` (`payroll_date`);

--
-- Indexes for table `portal_login_activity`
--
ALTER TABLE `portal_login_activity`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_pla_entity` (`entity_type`,`entity_id`),
  ADD KEY `idx_pla_created` (`created_at`);

--
-- Indexes for table `portal_notifications`
--
ALTER TABLE `portal_notifications`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_pn_recipient` (`recipient_type`,`recipient_id`),
  ADD KEY `idx_pn_unread` (`recipient_type`,`recipient_id`,`is_read`),
  ADD KEY `idx_pn_created` (`created_at`);

--
-- Indexes for table `portal_sessions`
--
ALTER TABLE `portal_sessions`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_ps_entity` (`entity_type`,`entity_id`),
  ADD KEY `idx_ps_token` (`refresh_token_hash`(32)),
  ADD KEY `idx_ps_expires` (`expires_at`);

--
-- Indexes for table `push_subscriptions`
--
ALTER TABLE `push_subscriptions`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `uniq_provider_subscription` (`provider`,`subscription_id`),
  ADD KEY `idx_push_subscriptions_user` (`user_id`),
  ADD KEY `idx_push_subscriptions_user_status` (`user_id`,`status`);

--
-- Indexes for table `saved_passenger_profiles`
--
ALTER TABLE `saved_passenger_profiles`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_spp_owner` (`owner_type`,`owner_id`),
  ADD KEY `idx_spp_last_name` (`last_name`),
  ADD KEY `idx_spp_id_number` (`identification_number`);

--
-- Indexes for table `seat_reservations`
--
ALTER TABLE `seat_reservations`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `booking_reference` (`booking_reference`),
  ADD KEY `idx_flight_series_id` (`flight_series_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_reservation_date` (`reservation_date`),
  ADD KEY `idx_booking_reference` (`booking_reference`),
  ADD KEY `idx_agent_id` (`agent_id`),
  ADD KEY `FK_seat_res_country` (`country_id`),
  ADD KEY `idx_linked_reservation_id` (`linked_reservation_id`),
  ADD KEY `idx_return_flight_series_id` (`return_flight_series_id`),
  ADD KEY `fk_sr_flight` (`flight_id`);

--
-- Indexes for table `settings`
--
ALTER TABLE `settings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `setting_key` (`setting_key`);

--
-- Indexes for table `staff`
--
ALTER TABLE `staff`
  ADD PRIMARY KEY (`id`),
  ADD KEY `fk_staff_department` (`department_id`),
  ADD KEY `idx_staff_designation` (`designation`),
  ADD KEY `idx_staff_manager` (`manager_id`);

--
-- Indexes for table `suppliers`
--
ALTER TABLE `suppliers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `supplier_code` (`supplier_code`);

--
-- Indexes for table `supplier_ledger`
--
ALTER TABLE `supplier_ledger`
  ADD PRIMARY KEY (`id`),
  ADD KEY `supplier_id` (`supplier_id`);

--
-- Indexes for table `ticket_exports`
--
ALTER TABLE `ticket_exports`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_te_booking` (`booking_id`);

--
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `accounts`
--
ALTER TABLE `accounts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `account_category`
--
ALTER TABLE `account_category`
  MODIFY `id` int(3) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `account_deletion_requests`
--
ALTER TABLE `account_deletion_requests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `account_ledger`
--
ALTER TABLE `account_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `account_types`
--
ALTER TABLE `account_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `agencies`
--
ALTER TABLE `agencies`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `agency_deposits`
--
ALTER TABLE `agency_deposits`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `agency_ledger`
--
ALTER TABLE `agency_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `agents`
--
ALTER TABLE `agents`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `agent_commissions`
--
ALTER TABLE `agent_commissions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `aircrafts`
--
ALTER TABLE `aircrafts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `airline_users`
--
ALTER TABLE `airline_users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `booking_amendments`
--
ALTER TABLE `booking_amendments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `booking_passengers`
--
ALTER TABLE `booking_passengers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `booking_status_history`
--
ALTER TABLE `booking_status_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cabin_classes`
--
ALTER TABLE `cabin_classes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cargo_audit_logs`
--
ALTER TABLE `cargo_audit_logs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cargo_bookings`
--
ALTER TABLE `cargo_bookings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cargo_capacity_overrides`
--
ALTER TABLE `cargo_capacity_overrides`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cargo_freight_rates`
--
ALTER TABLE `cargo_freight_rates`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cargo_handling_fees`
--
ALTER TABLE `cargo_handling_fees`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cargo_shc_charges`
--
ALTER TABLE `cargo_shc_charges`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `cargo_tariffs`
--
ALTER TABLE `cargo_tariffs`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `Category`
--
ALTER TABLE `Category`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `chart_of_accounts`
--
ALTER TABLE `chart_of_accounts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `chat_messages`
--
ALTER TABLE `chat_messages`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `chat_rooms`
--
ALTER TABLE `chat_rooms`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `chat_room_members`
--
ALTER TABLE `chat_room_members`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `Country`
--
ALTER TABLE `Country`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `crew`
--
ALTER TABLE `crew`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `crew_assignments`
--
ALTER TABLE `crew_assignments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `currencies`
--
ALTER TABLE `currencies`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `delete_acc`
--
ALTER TABLE `delete_acc`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `departments`
--
ALTER TABLE `departments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `destinations`
--
ALTER TABLE `destinations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `device_tokens`
--
ALTER TABLE `device_tokens`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `exception_types`
--
ALTER TABLE `exception_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `exchange_rates`
--
ALTER TABLE `exchange_rates`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `expenses`
--
ALTER TABLE `expenses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `expense_categories`
--
ALTER TABLE `expense_categories`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `expense_types`
--
ALTER TABLE `expense_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `experiences`
--
ALTER TABLE `experiences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `fare_history`
--
ALTER TABLE `fare_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `flights`
--
ALTER TABLE `flights`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `flight_crew`
--
ALTER TABLE `flight_crew`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `flight_exceptions`
--
ALTER TABLE `flight_exceptions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `flight_routes`
--
ALTER TABLE `flight_routes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `flight_series`
--
ALTER TABLE `flight_series`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `float_requests`
--
ALTER TABLE `float_requests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `fueling`
--
ALTER TABLE `fueling`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `hotels`
--
ALTER TABLE `hotels`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `iata_codes`
--
ALTER TABLE `iata_codes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `journal_entries`
--
ALTER TABLE `journal_entries`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `journal_entry_lines`
--
ALTER TABLE `journal_entry_lines`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `loyalty_points_history`
--
ALTER TABLE `loyalty_points_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `loyalty_tiers`
--
ALTER TABLE `loyalty_tiers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `luggage`
--
ALTER TABLE `luggage`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notices`
--
ALTER TABLE `notices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `offers`
--
ALTER TABLE `offers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `passengers`
--
ALTER TABLE `passengers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `passenger_disruptions`
--
ALTER TABLE `passenger_disruptions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `password_resets`
--
ALTER TABLE `password_resets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `payment_transactions`
--
ALTER TABLE `payment_transactions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `payroll`
--
ALTER TABLE `payroll`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `portal_login_activity`
--
ALTER TABLE `portal_login_activity`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `portal_notifications`
--
ALTER TABLE `portal_notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `portal_sessions`
--
ALTER TABLE `portal_sessions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `push_subscriptions`
--
ALTER TABLE `push_subscriptions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `saved_passenger_profiles`
--
ALTER TABLE `saved_passenger_profiles`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `seat_reservations`
--
ALTER TABLE `seat_reservations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `settings`
--
ALTER TABLE `settings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `staff`
--
ALTER TABLE `staff`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `suppliers`
--
ALTER TABLE `suppliers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `supplier_ledger`
--
ALTER TABLE `supplier_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `ticket_exports`
--
ALTER TABLE `ticket_exports`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `account_deletion_requests`
--
ALTER TABLE `account_deletion_requests`
  ADD CONSTRAINT `account_deletion_requests_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `airline_users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `account_ledger`
--
ALTER TABLE `account_ledger`
  ADD CONSTRAINT `fk_account_ledger_account` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `agent_commissions`
--
ALTER TABLE `agent_commissions`
  ADD CONSTRAINT `ac_fk_agent` FOREIGN KEY (`agent_id`) REFERENCES `agents` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `ac_fk_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `bookings_fk_agency` FOREIGN KEY (`agency_id`) REFERENCES `agencies` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `bookings_fk_agent` FOREIGN KEY (`agent_id`) REFERENCES `agents` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_bookings_flight` FOREIGN KEY (`flight_id`) REFERENCES `flights` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `booking_amendments`
--
ALTER TABLE `booking_amendments`
  ADD CONSTRAINT `ba_fk_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `booking_passengers`
--
ALTER TABLE `booking_passengers`
  ADD CONSTRAINT `fk_bp_flight` FOREIGN KEY (`flight_id`) REFERENCES `flights` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `booking_status_history`
--
ALTER TABLE `booking_status_history`
  ADD CONSTRAINT `bsh_fk_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `crew_assignments`
--
ALTER TABLE `crew_assignments`
  ADD CONSTRAINT `fk_ca_crew` FOREIGN KEY (`crew_id`) REFERENCES `crew` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_ca_flight` FOREIGN KEY (`flight_id`) REFERENCES `flights` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `expense_types`
--
ALTER TABLE `expense_types`
  ADD CONSTRAINT `expense_types_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `expense_categories` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `fare_history`
--
ALTER TABLE `fare_history`
  ADD CONSTRAINT `FK_fare_history_route` FOREIGN KEY (`route_id`) REFERENCES `flight_routes` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `flights`
--
ALTER TABLE `flights`
  ADD CONSTRAINT `fk_flights_aircraft` FOREIGN KEY (`aircraft_id`) REFERENCES `aircrafts` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_flights_series` FOREIGN KEY (`series_id`) REFERENCES `flight_series` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `flight_exceptions`
--
ALTER TABLE `flight_exceptions`
  ADD CONSTRAINT `fk_fe_flight` FOREIGN KEY (`flight_id`) REFERENCES `flights` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_fe_type` FOREIGN KEY (`exception_type`) REFERENCES `exception_types` (`id`);

--
-- Constraints for table `flight_routes`
--
ALTER TABLE `flight_routes`
  ADD CONSTRAINT `FK_route_from` FOREIGN KEY (`from_destination_id`) REFERENCES `destinations` (`id`) ON UPDATE CASCADE,
  ADD CONSTRAINT `FK_route_to` FOREIGN KEY (`to_destination_id`) REFERENCES `destinations` (`id`) ON UPDATE CASCADE;

--
-- Constraints for table `float_requests`
--
ALTER TABLE `float_requests`
  ADD CONSTRAINT `fr_fk_agency` FOREIGN KEY (`agency_id`) REFERENCES `agencies` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `passenger_disruptions`
--
ALTER TABLE `passenger_disruptions`
  ADD CONSTRAINT `fk_pd_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `fk_pd_flight` FOREIGN KEY (`flight_id`) REFERENCES `flights` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `seat_reservations`
--
ALTER TABLE `seat_reservations`
  ADD CONSTRAINT `FK_seat_res_country` FOREIGN KEY (`country_id`) REFERENCES `Country` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_sr_flight` FOREIGN KEY (`flight_id`) REFERENCES `flights` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `ticket_exports`
--
ALTER TABLE `ticket_exports`
  ADD CONSTRAINT `te_fk_booking` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
