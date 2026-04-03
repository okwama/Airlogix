-- phpMyAdmin SQL Dump
-- version 5.2.2
-- https://www.phpmyadmin.net/
--
-- Host: localhost:3306
-- Generation Time: Mar 31, 2026 at 11:21 PM
-- Server version: 10.6.24-MariaDB-cll-lve
-- PHP Version: 8.4.18

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Database: `impulsep_royal`
--

DELIMITER $$
--
-- Procedures
--
CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `BulkInsertProductReports` (IN `p_journey_plan_id` INT, IN `p_client_id` INT, IN `p_user_id` INT, IN `p_products_json` JSON)   BEGIN
    DECLARE v_product_count INT DEFAULT 0;
    DECLARE v_current_index INT DEFAULT 0;
    DECLARE v_product_name VARCHAR(191);
    DECLARE v_quantity INT;
    DECLARE v_comment VARCHAR(191);
    DECLARE v_product_id INT;
    DECLARE v_inserted_count INT DEFAULT 0;
    
    SET v_product_count = JSON_LENGTH(p_products_json);
    
    WHILE v_current_index < v_product_count DO
        SET v_product_name = JSON_UNQUOTE(JSON_EXTRACT(p_products_json, CONCAT('$[', v_current_index, '].productName')));
        SET v_quantity = JSON_UNQUOTE(JSON_EXTRACT(p_products_json, CONCAT('$[', v_current_index, '].quantity')));
        SET v_comment = JSON_UNQUOTE(JSON_EXTRACT(p_products_json, CONCAT('$[', v_current_index, '].comment')));
        SET v_product_id = JSON_UNQUOTE(JSON_EXTRACT(p_products_json, CONCAT('$[', v_current_index, '].productId')));
        
        INSERT INTO ProductReport (
            reportId, productName, quantity, comment, clientId, userId, productId, createdAt
        ) VALUES (
            p_journey_plan_id, v_product_name, v_quantity, v_comment, p_client_id, p_user_id, v_product_id, NOW(3)
        );
        
        SET v_inserted_count = v_inserted_count + 1;
        SET v_current_index = v_current_index + 1;
    END WHILE;
    
    SELECT 'SUCCESS' AS status, v_inserted_count AS inserted_count;
END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `CapLoginSessionDurations` ()   BEGIN
    UPDATE LoginHistory 
    SET 
        sessionEnd = CASE 
            WHEN TIMESTAMPDIFF(MINUTE, sessionStart, NOW()) > 480 
            THEN CONCAT(DATE(sessionStart), ' 18:00:00')  -- Use sessionStart's date
            ELSE NOW()
        END,
        duration = LEAST(TIMESTAMPDIFF(MINUTE, sessionStart, NOW()), 480),
        status = 2
    WHERE 
        status = 1 
        AND sessionEnd IS NULL;
END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `CreateBasicOrder` (IN `p_client_id` INT, IN `p_salesrep_id` INT, IN `p_notes` TEXT, IN `p_so_number` VARCHAR(20), IN `p_total_amount` DECIMAL(15,2), OUT `p_order_id` INT, OUT `p_success` TINYINT, OUT `p_error_message` TEXT)   proc_label: BEGIN
    DECLARE v_order_id INT;

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_message = 'Database error occurred';
    END;

    START TRANSACTION;

    -- Validate client exists
    IF NOT EXISTS (SELECT 1 FROM Clients WHERE id = p_client_id AND status = 0) THEN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_message = 'Invalid client or client is inactive';
        LEAVE proc_label;
    END IF;

    -- Validate sales rep exists
    IF NOT EXISTS (SELECT 1 FROM SalesRep WHERE id = p_salesrep_id AND status = 1) THEN
        ROLLBACK;
        SET p_success = FALSE;
        SET p_error_message = 'Invalid sales rep or sales rep is inactive';
        LEAVE proc_label;
    END IF;

    -- Insert into sales_orders
    INSERT INTO sales_orders (
        so_number,
        client_id,
        order_date,
        expected_delivery_date,
        subtotal,
        tax_amount,
        total_amount,
        net_price,
        notes,
        salesrep,
        rider_id,
        assigned_at,
        status,
        my_status
    ) VALUES (
        p_so_number,
        p_client_id,
        CURDATE(),
        DATE_ADD(CURDATE(), INTERVAL 7 DAY),
        p_total_amount,
        0,
        p_total_amount,
        p_total_amount,
        p_notes,
        p_salesrep_id,
        0,
        NULL,
        'draft',
        0
    );

    SET v_order_id = LAST_INSERT_ID();

    COMMIT;

    SET p_order_id = v_order_id;
    SET p_success = TRUE;
    SET p_error_message = NULL;

END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `GetClockSessions` (IN `p_userId` INT, IN `p_startDate` DATE, IN `p_endDate` DATE, IN `p_limit` INT)   BEGIN
    -- Set default limit if NULL
    SET p_limit = COALESCE(p_limit, 50);
    
    -- Get session history with optional date range
    SELECT 
        id,
        userId,
        sessionStart,
        sessionEnd,
        duration,
        status,
        timezone,
        -- Formatted fields for frontend
        DATE_FORMAT(sessionStart, '%Y-%m-%d %H:%i:%s') as formattedStart,
        DATE_FORMAT(sessionEnd, '%Y-%m-%d %H:%i:%s') as formattedEnd,
        CASE 
            WHEN duration >= 60 THEN CONCAT(FLOOR(duration/60), 'h ', MOD(duration, 60), 'm')
            ELSE CONCAT(duration, 'm')
        END as formattedDuration,
        CASE WHEN status = 1 THEN 1 ELSE 0 END as isActive
    FROM LoginHistory 
    WHERE userId = p_userId
        AND (p_startDate IS NULL OR DATE(sessionStart) >= p_startDate)
        AND (p_endDate IS NULL OR DATE(sessionStart) <= p_endDate)
    ORDER BY sessionStart DESC
    LIMIT p_limit;
END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `GetJourneyPlans` (IN `p_userId` INT, IN `p_status` INT, IN `p_targetDate` DATE, IN `p_page` INT, IN `p_limit` INT, IN `p_offset` INT)   BEGIN
    -- Set default values
    SET p_page = COALESCE(p_page, 1);
    SET p_limit = COALESCE(p_limit, 20);
    SET p_offset = COALESCE(p_offset, 0);
    
    -- Get journey plans with client and user information
    SELECT 
        jp.id,
        jp.userId,
        jp.clientId,
        jp.date,
        jp.time,
        jp.status,
        jp.checkInTime,
        jp.latitude,
        jp.longitude,
        jp.imageUrl,
        jp.notes,
        jp.checkoutLatitude,
        jp.checkoutLongitude,
        jp.checkoutTime,
        jp.showUpdateLocation,
        jp.routeId,
        -- Client information
        c.id as 'client.id',
        c.name as 'client.name',
        c.contact as 'client.contact',
        c.email as 'client.email',
        c.address as 'client.address',
        c.status as 'client.status',
        c.route_id as 'client.route_id',
        c.route_name as 'client.route_name',
        c.countryId as 'client.countryId',
        c.region_id as 'client.region_id',
        c.created_at as 'client.created_at',
        -- User/SalesRep information
        sr.id as 'user.id',
        sr.name as 'user.name',
        sr.email as 'user.email',
        sr.phoneNumber as 'user.phoneNumber',
        sr.role as 'user.role',
        sr.status as 'user.status',
        sr.countryId as 'user.countryId',
        sr.region_id as 'user.region_id',
        sr.route_id as 'user.route_id',
        sr.route as 'user.route',
        sr.createdAt as 'user.createdAt',
        sr.updatedAt as 'user.updatedAt'
    FROM JourneyPlan jp
    LEFT JOIN Clients c ON jp.clientId = c.id
    LEFT JOIN SalesRep sr ON jp.userId = sr.id
    WHERE (p_userId = 0 OR jp.userId = p_userId)
        AND (p_status = -1 OR jp.status = p_status)
        AND (p_targetDate IS NULL OR DATE(jp.date) = p_targetDate)
    ORDER BY jp.date DESC, jp.time DESC
    LIMIT p_limit OFFSET p_offset;
    
    -- Get total count for pagination
    SELECT COUNT(*) as total
    FROM JourneyPlan jp
    WHERE (p_userId = 0 OR jp.userId = p_userId)
        AND (p_status = -1 OR jp.status = p_status)
        AND (p_targetDate IS NULL OR DATE(jp.date) = p_targetDate);
END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `sp_clock_in` (IN `p_user_id` INT, IN `p_client_time` DATETIME)   BEGIN
  DECLARE v_today DATE;
  DECLARE v_active_id INT;
  DECLARE v_completed_id INT;

  SET v_today = DATE(p_client_time);

  -- 1) Auto-close any previous-day active sessions at 18:00 (Nairobi time)
  UPDATE LoginHistory lh
     SET lh.status = 2,
         lh.sessionEnd = CONCAT(DATE(lh.sessionStart), ' 18:00:00'),
         lh.duration = TIMESTAMPDIFF(MINUTE, lh.sessionStart, CONCAT(DATE(lh.sessionStart), ' 18:00:00'))
   WHERE lh.userId = p_user_id
     AND lh.status = 1
     AND DATE(lh.sessionStart) < v_today;

  -- 2) If an active session exists today, continue it
  SELECT id INTO v_active_id
    FROM LoginHistory
   WHERE userId = p_user_id
     AND status = 1
     AND DATE(sessionStart) = v_today
   ORDER BY sessionStart DESC
   LIMIT 1;

  IF v_active_id IS NOT NULL THEN
    SELECT 'ok' AS result, 'Continuing existing session' AS message, v_active_id AS sessionId;
  ELSE
    -- 3) If a completed session exists today, re-open it (continue)
    SELECT id INTO v_completed_id
      FROM LoginHistory
     WHERE userId = p_user_id
       AND status = 2
       AND DATE(sessionStart) = v_today
     ORDER BY sessionStart DESC
     LIMIT 1;

    IF v_completed_id IS NOT NULL THEN
      UPDATE LoginHistory
         SET status = 1,
             sessionEnd = NULL,
             duration = 0
       WHERE id = v_completed_id;

      SELECT 'ok' AS result, 'Continuing today\'s session' AS message, v_completed_id AS sessionId;
    ELSE
      -- 4) Otherwise create a new session
      INSERT INTO LoginHistory (userId, timezone, duration, status, sessionEnd, sessionStart)
      VALUES (p_user_id, 'Africa/Nairobi', 0, 1, NULL, p_client_time);

      SELECT 'ok' AS result, 'Successfully clocked in' AS message, LAST_INSERT_ID() AS sessionId;
    END IF;
  END IF;
END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `sp_clock_out` (IN `p_user_id` INT, IN `p_client_time` DATETIME)   BEGIN
  DECLARE v_today DATE;
  DECLARE v_session_id INT;
  DECLARE v_start DATETIME;
  DECLARE v_end DATETIME;
  DECLARE v_duration INT;

  SET v_today = DATE(p_client_time);

  -- 1) Find today's active session
  SELECT id, sessionStart
    INTO v_session_id, v_start
    FROM LoginHistory
   WHERE userId = p_user_id
     AND status = 1
     AND DATE(sessionStart) = v_today
   ORDER BY sessionStart DESC
   LIMIT 1;

  IF v_session_id IS NULL THEN
    SELECT 'fail' AS result, 'You are not currently clocked in.' AS message;
  ELSE
    -- 2) Cap duration at 8 hours or 18:00 end time, whichever applies
    SET v_end = p_client_time;
    SET v_duration = TIMESTAMPDIFF(MINUTE, v_start, v_end);

    IF v_duration > 480 THEN
      SET v_end = CONCAT(DATE(v_start), ' 18:00:00');
      SET v_duration = TIMESTAMPDIFF(MINUTE, v_start, v_end);
    END IF;

    -- 3) Update session
    UPDATE LoginHistory
       SET status = 2,
           sessionEnd = v_end,
           duration = v_duration
     WHERE id = v_session_id;

    SELECT 'ok' AS result, 'Successfully clocked out' AS message, v_duration AS durationMinutes, v_session_id AS sessionId;
  END IF;
END$$

CREATE DEFINER=`impulsep`@`localhost` PROCEDURE `sp_dashboard_summary` (IN `p_user_id` INT, IN `p_date` DATE)   BEGIN
  DECLARE v_date DATE;
  SET v_date = IFNULL(p_date, CURDATE());

  /* Cards schema: id, title, mainValue, subValue, type, status */

  /* Orders + View Orders */
  SELECT 'orders' AS id,
         'Create Order' AS title,
         'New Order' AS mainValue,
         CONCAT(IFNULL((SELECT COUNT(*) FROM sales_orders so WHERE DATE(so.order_date) = v_date), 0), ' Total Orders') AS subValue,
         'orders' AS type,
         'normal' AS status
  UNION ALL
  SELECT 'viewOrders',
         'View Orders',
         CONCAT(IFNULL((SELECT COUNT(*) FROM sales_orders so WHERE DATE(so.order_date) = v_date), 0), ' Orders') AS mainValue,
         CONCAT(IFNULL((SELECT COUNT(*) FROM sales_orders so WHERE so.status IN ('in payment','draft')), 0), ' Pending') AS subValue,
         'viewOrders',
         'normal'

  /* Visits */
  UNION ALL
  SELECT 'visits' AS id,
         'Visits' AS title,
         CONCAT(IFNULL((SELECT COUNT(*) FROM JourneyPlan jp WHERE jp.userId = p_user_id AND DATE(jp.date) = v_date AND jp.checkInTime IS NOT NULL), 0),
                '/',
                IFNULL((SELECT COUNT(*) FROM JourneyPlan jp2 WHERE jp2.userId = p_user_id AND DATE(jp2.date) = v_date), 0),
                ' Done') AS mainValue,
         CONCAT(
           GREATEST(
             IFNULL((SELECT COUNT(*) FROM JourneyPlan jp3 WHERE jp3.userId = p_user_id AND DATE(jp3.date) = v_date), 0)
             - IFNULL((SELECT COUNT(*) FROM JourneyPlan jp4 WHERE jp4.userId = p_user_id AND DATE(jp4.date) = v_date AND jp4.checkInTime IS NOT NULL), 0),
             0
           ),
           ' Remaining'
         ) AS subValue,
         'visits' AS type,
         CASE WHEN (
           IFNULL((SELECT COUNT(*) FROM JourneyPlan jp3 WHERE jp3.userId = p_user_id AND DATE(jp3.date) = v_date), 0)
           - IFNULL((SELECT COUNT(*) FROM JourneyPlan jp4 WHERE jp4.userId = p_user_id AND DATE(jp4.date) = v_date AND jp4.checkInTime IS NOT NULL), 0)
         ) = 0 THEN 'success' ELSE 'normal' END AS status

  /* Clients */
  UNION ALL
  SELECT 'clients',
         'Clients',
         CONCAT(IFNULL((SELECT COUNT(*) FROM Clients c WHERE c.status = 1), 0), ' Active') AS mainValue,
         CONCAT(IFNULL((SELECT COUNT(*) FROM Clients c2 WHERE DATE(c2.created_at) = v_date), 0), ' Today') AS subValue,
         'clients',
         'normal'

  /* Tasks */
  UNION ALL
  SELECT 'tasks',
         'Tasks',
         CONCAT(IFNULL((SELECT COUNT(*) FROM tasks t WHERE t.salesRepId = p_user_id AND t.status = 'pending'), 0), ' Pending') AS mainValue,
         CONCAT(IFNULL((SELECT COUNT(*) FROM tasks t2 
                         WHERE t2.salesRepId = p_user_id 
                           AND t2.status = 'pending' 
                           AND (DATE(t2.date) = v_date OR (t2.date IS NULL AND DATE(t2.createdAt) = v_date))
                       ), 0), ' Due Today') AS subValue,
         'tasks',
         CASE WHEN IFNULL((SELECT COUNT(*) FROM tasks t2 
                             WHERE t2.salesRepId = p_user_id 
                               AND t2.status = 'pending' 
                               AND (DATE(t2.date) = v_date OR (t2.date IS NULL AND DATE(t2.createdAt) = v_date))
                           ), 0) > 0 THEN 'warning' ELSE 'normal' END AS status

  /* Notices */
  UNION ALL
  SELECT 'notices',
         'Notices',
         CONCAT(IFNULL((SELECT COUNT(*) FROM notices n WHERE DATE(n.created_at) = v_date), 0), ' New') AS mainValue,
         CONCAT(IFNULL((SELECT COUNT(*) FROM notices n2 WHERE DATE(n2.created_at) = v_date AND n2.status = 1), 0), ' Important') AS subValue,
         'notices',
         CASE WHEN IFNULL((SELECT COUNT(*) FROM notices n2 WHERE DATE(n2.created_at) = v_date AND n2.status = 1), 0) > 0 THEN 'warning' ELSE 'normal' END

  /* Journey Plans */
  UNION ALL
  SELECT 'journeyPlans',
         'Journey Plans',
         CONCAT(IFNULL((SELECT COUNT(*) FROM JourneyPlan jp WHERE DATE(jp.date) = v_date AND (jp.userId = p_user_id OR p_user_id IS NULL)), 0), ' Routes') AS mainValue,
         '0 Stops' AS subValue,
         'journeyPlans',
         'normal'

  /* Clock In/Out */
  UNION ALL
  SELECT 'clockInOut',
         'Clock In/Out',
         CASE WHEN (
           SELECT lh.status FROM LoginHistory lh 
           WHERE lh.userId = p_user_id 
             AND DATE(CAST(lh.sessionStart AS DATETIME)) = v_date
           ORDER BY CAST(lh.sessionStart AS DATETIME) DESC LIMIT 1
         ) = 1 THEN 'Clocked In' ELSE 'Clocked Out' END AS mainValue,
         COALESCE(
           (SELECT DATE_FORMAT(CAST(lh.sessionStart AS DATETIME), '%H:%i')
              FROM LoginHistory lh 
             WHERE lh.userId = p_user_id 
               AND DATE(CAST(lh.sessionStart AS DATETIME)) = v_date
             ORDER BY CAST(lh.sessionStart AS DATETIME) DESC LIMIT 1),
           'Not Started'
         ) AS subValue,
         'clockInOut',
         CASE WHEN (
           SELECT lh.status FROM LoginHistory lh 
           WHERE lh.userId = p_user_id 
             AND DATE(CAST(lh.sessionStart AS DATETIME)) = v_date
           ORDER BY CAST(lh.sessionStart AS DATETIME) DESC LIMIT 1
         ) = 1 THEN 'success' ELSE 'normal' END AS status

  /* Leaves */
  UNION ALL
  SELECT 'leaves',
         'Leaves',
         CONCAT(IFNULL((SELECT COUNT(*) FROM leave_requests lr WHERE lr.employee_id = p_user_id AND lr.status = 'approved'), 0), ' Approved') AS mainValue,
         CONCAT(IFNULL((SELECT COUNT(*) FROM leave_requests lr2 WHERE lr2.employee_id = p_user_id AND lr2.status = 'pending'), 0), ' Pending') AS subValue,
         'leaves',
         CASE WHEN IFNULL((SELECT COUNT(*) FROM leave_requests lr2 WHERE lr2.employee_id = p_user_id AND lr2.status = 'pending'), 0) > 0 THEN 'warning' ELSE 'normal' END

  /* Static cards */
  UNION ALL
  SELECT 'upliftSales','Uplift Sales','3 Active','Promotions','upliftSales','normal'
  UNION ALL
  SELECT 'returns','Returns','2 Pending','Returns','returns','normal'
  UNION ALL
  SELECT 'profile','Profile','View/Edit','Profile','profile','normal'
  ;
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Table structure for table `account_category`
--

CREATE TABLE `account_category` (
  `id` int(3) NOT NULL,
  `name` varchar(20) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `account_category`
--

INSERT INTO `account_category` (`id`, `name`) VALUES
(1, 'Assets'),
(2, 'Liabilities'),
(3, 'Equity'),
(4, 'Revenue'),
(5, 'Expenses');

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

--
-- Dumping data for table `account_deletion_requests`
--

INSERT INTO `account_deletion_requests` (`id`, `user_id`, `full_name`, `email`, `reason`, `status`, `created_at`) VALUES
(1, 3, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', 't', 'pending', '2026-03-02 08:32:59');

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

--
-- Dumping data for table `account_types`
--

INSERT INTO `account_types` (`id`, `account_type`, `account_category`, `created_at`) VALUES
(4, 'Fixed Assets', 1, '2025-06-15 12:20:35'),
(5, 'Non-current Assets', 1, '2025-06-15 12:23:45'),
(6, 'Current Assets', 1, '2025-06-15 12:24:10'),
(7, 'Receivable', 1, '2025-06-15 12:25:37'),
(8, 'Prepayment', 1, '2025-06-15 12:26:44'),
(9, 'Bank and Cash', 1, '2025-06-15 12:27:20'),
(10, 'Payable', 2, '2025-06-15 12:28:32'),
(11, 'Current Liabilities', 2, '2025-06-15 12:29:50'),
(12, 'Credit Card', 2, '2025-06-15 12:30:13'),
(13, 'Equity', 3, '2025-06-15 12:30:59'),
(14, 'Income', 4, '2025-06-15 12:31:33'),
(15, 'Cost of Revenue', 5, '2025-06-15 12:32:33'),
(16, 'Expense', 5, '2025-06-15 12:33:02'),
(17, 'Depreciation', 5, '2025-06-15 12:35:11'),
(18, 'Current Year Earnings', 3, '2025-06-15 12:36:17'),
(19, 'Other Income', 4, '2025-06-15 15:04:27');

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
  `booking_limit` int(11) DEFAULT NULL,
  `credit_limit` decimal(10,2) DEFAULT NULL,
  `max_pax_per_booking` int(11) DEFAULT NULL,
  `default_currency` varchar(3) DEFAULT NULL,
  `credit_days` int(11) DEFAULT NULL,
  `payment_limit` decimal(10,2) DEFAULT NULL,
  `balance` decimal(10,2) NOT NULL DEFAULT 0.00,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `agencies`
--

INSERT INTO `agencies` (`id`, `name`, `contact`, `city`, `country`, `booking_limit`, `credit_limit`, `max_pax_per_booking`, `default_currency`, `credit_days`, `payment_limit`, `balance`, `created_at`, `updated_at`) VALUES
(1, 'PAGF-SI', '9999', 'Nairobi', 'Comoros', 80, 900000.00, 34, 'KMF', 365, 8999999.99, 501477.00, '2025-12-04 18:28:30', '2025-12-06 11:10:26'),
(2, 'ROYAL PACK ', 'SLIM MOURID', NULL, 'Comoros', 9000000, 9000000.00, 34, 'KMF', 365, 9000000.00, 2140.00, '2025-12-05 19:57:56', '2025-12-06 09:03:12');

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

--
-- Dumping data for table `agency_deposits`
--

INSERT INTO `agency_deposits` (`id`, `agency_id`, `account_id`, `amount`, `date_paid`, `description`, `payment_method`, `reference`, `created_at`, `updated_at`) VALUES
(1, 2, 2, 12.00, '2025-12-06', '2', 'Bank Transfer', 'q2', '2025-12-06 09:03:13', '2025-12-06 09:03:13'),
(2, 1, 2, 3000.00, '2025-12-06', 'test', 'Bank Transfer', 'test', '2025-12-06 11:10:27', '2025-12-06 11:10:27');

-- --------------------------------------------------------

--
-- Table structure for table `agency_ledger`
--

CREATE TABLE `agency_ledger` (
  `id` int(11) NOT NULL,
  `agency_id` int(11) NOT NULL,
  `transaction_date` date NOT NULL,
  `description` text DEFAULT NULL,
  `debit` decimal(15,2) NOT NULL DEFAULT 0.00,
  `credit` decimal(15,2) NOT NULL DEFAULT 0.00,
  `balance` decimal(15,2) NOT NULL DEFAULT 0.00,
  `reference` varchar(100) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `agency_ledger`
--

INSERT INTO `agency_ledger` (`id`, `agency_id`, `transaction_date`, `description`, `debit`, `credit`, `balance`, `reference`, `created_at`, `updated_at`) VALUES
(1, 1, '2025-12-05', 'Balance adjustment - Added 450000.00', 450000.00, 0.00, 50000.00, 'BALANCE_ADJUSTMENT', '2025-12-05 13:28:18', '2025-12-05 13:28:18'),
(2, 1, '2025-12-05', 'Booking payment - BKMISWPCAZ242I', 0.00, 300.00, 49700.00, 'BKMISWPCAZ242I', '2025-12-05 13:34:34', '2025-12-05 13:34:34'),
(3, 1, '2025-12-05', 'Booking payment - BKMISWZIQL3NQ7', 0.00, 300.00, 49400.00, 'BKMISWZIQL3NQ7', '2025-12-05 13:42:29', '2025-12-05 13:42:29'),
(4, 1, '2025-12-05', 'Booking payment - BKMISX4UQBU8Q8', 0.00, 300.00, 49100.00, 'BKMISX4UQBU8Q8', '2025-12-05 13:46:38', '2025-12-05 13:46:38'),
(5, 2, '2025-12-06', 'M2M2M2', 2000.00, 0.00, 2000.00, 'M2M2M2', '2025-12-06 07:32:12', '2025-12-06 07:32:12'),
(6, 2, '2025-12-06', 'we', 20.00, 0.00, 2020.00, '234', '2025-12-06 07:36:40', '2025-12-06 07:36:40'),
(7, 2, '2025-12-06', 'we', 20.00, 0.00, 2040.00, '234', '2025-12-06 07:36:44', '2025-12-06 07:36:44'),
(8, 2, '2025-12-06', 'we', 20.00, 0.00, 2060.00, '234', '2025-12-06 07:36:45', '2025-12-06 07:36:45'),
(9, 2, '2025-12-06', 'we', 20.00, 0.00, 2080.00, '234', '2025-12-06 07:38:17', '2025-12-06 07:38:17'),
(10, 2, '2025-12-06', 'ff', 12.00, 0.00, 2092.00, 'ff', '2025-12-06 08:04:36', '2025-12-06 08:04:36'),
(11, 1, '2025-12-06', 'w', 11.00, 0.00, 49111.00, 'w', '2025-12-06 08:09:00', '2025-12-06 08:09:00'),
(12, 1, '2025-12-06', 'w', 11.00, 0.00, 49122.00, 'w', '2025-12-06 08:13:16', '2025-12-06 08:13:16'),
(13, 1, '2025-12-06', 'w', 11.00, 0.00, 49133.00, 'w', '2025-12-06 08:13:20', '2025-12-06 08:13:20'),
(14, 1, '2025-12-06', 'w', 11.00, 0.00, 49144.00, 'w', '2025-12-06 08:13:24', '2025-12-06 08:13:24'),
(15, 1, '2025-12-06', 'w', 11.00, 0.00, 49155.00, 'w', '2025-12-06 08:13:55', '2025-12-06 08:13:55'),
(16, 1, '2025-12-06', 'w', 11.00, 0.00, 49166.00, 'w', '2025-12-06 08:15:14', '2025-12-06 08:15:14'),
(17, 1, '2025-12-06', 'w', 11.00, 0.00, 49177.00, 'w', '2025-12-06 08:16:06', '2025-12-06 08:16:06'),
(18, 2, '2025-12-06', 'e', 12.00, 0.00, 2104.00, 'r', '2025-12-06 08:55:53', '2025-12-06 08:55:53'),
(19, 2, '2025-12-06', '2', 12.00, 0.00, 2116.00, 'q2', '2025-12-06 09:00:59', '2025-12-06 09:00:59'),
(20, 2, '2025-12-06', '2', 12.00, 0.00, 2128.00, 'q2', '2025-12-06 09:02:25', '2025-12-06 09:02:25'),
(21, 2, '2025-12-06', '2', 12.00, 0.00, 2140.00, 'q2', '2025-12-06 09:03:12', '2025-12-06 09:03:12'),
(22, 1, '2025-12-06', 'Booking payment - BKMIU6WCHOOEOT', 0.00, 700.00, 48477.00, 'BKMIU6WCHOOEOT', '2025-12-06 11:07:44', '2025-12-06 11:07:44'),
(23, 1, '2025-12-06', 'test', 3000.00, 0.00, 51477.00, 'test', '2025-12-06 11:10:26', '2025-12-06 11:10:26');

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
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `agents`
--

INSERT INTO `agents` (`id`, `name`, `email`, `country`, `contact`, `agency_id`, `use_deposit`, `created_at`, `updated_at`) VALUES
(1, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', 'Kenya', '77776', 1, 1, '2025-12-05 11:02:43', '2025-12-05 11:02:43');

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

--
-- Dumping data for table `aircrafts`
--

INSERT INTO `aircrafts` (`id`, `name`, `registration`, `capacity`, `max_cargo_weight`, `category_id`, `created_by`, `status`, `calendar_color`, `created_at`, `updated_at`) VALUES
(1, 'EMB 120', 'EMB 120', 30, 600.00, 3, NULL, 'active', '#3B82F6', '2025-11-28 15:31:49', '2025-11-28 19:55:05'),
(6, 'DASH 8-200', 'DASH 8-200', 37, 600.00, 3, '9', 'active', '#3B82F6', '2025-11-28 16:05:59', '2025-11-28 19:55:36'),
(7, 'D6-MAM(C19)', 'D6-MAM(C19)', 19, 600.00, NULL, '9', 'active', '#a8050d', '2025-11-28 19:55:29', '2025-12-05 14:57:09'),
(8, 'Saab 340', 'Saab 340', 34, 600.00, NULL, '9', 'active', '#3B82F6', '2025-11-28 19:56:13', '2025-11-28 19:56:13');

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

--
-- Dumping data for table `airline_users`
--

INSERT INTO `airline_users` (`id`, `phone_number`, `email`, `password_hash`, `first_name`, `last_name`, `date_of_birth`, `nationality`, `passport_number`, `passport_expiry_date`, `frequent_flyer_number`, `member_club`, `loyalty_points`, `profile_photo_url`, `status`, `created_at`, `updated_at`, `password_reset_code`, `password_reset_expires_at`, `deletion_status`) VALUES
(1, '0706166875', 'bennjiokwama@gmail.com', '$2b$10$n0rsM50QpFHZTd0UT2fgOe0B8RzASVcI2U4lj8VYM3NWqP/q3Irxm', 'Benjamin', 'Okwama', '1997-04-23', 'Kenyan', 'BK908881', '2030-12-25', NULL, 'BRONZE', 0, 'https://res.cloudinary.com/otienobryan/image/upload/v1769551316/profile_photos/ctcsdiwklunjmipdtsqj.jpg', 'active', '2025-12-01 13:31:04', '2026-02-25 09:53:36', NULL, NULL, 'active'),
(2, '0734343854', 'test-1769532570@example.com', '$2y$12$59MahfHpAOY.lay8EJRH/.SG9cV/pL/O.ekd1Rzii.VcefznW.Puq', 'Test', 'User', NULL, NULL, NULL, NULL, NULL, 'BRONZE', 0, NULL, 'active', '2026-01-27 16:49:30', '2026-01-27 16:49:31', NULL, NULL, 'active'),
(3, '0790193625', 'bryanotieno09@gmail.com', '$2y$10$oGea/PovBz2farBZ4YdfXuPR01BnvLjAc9nPSPAoAwT41nk4PXLJ6', 'bryan', 'otieno', NULL, NULL, NULL, NULL, NULL, 'BRONZE', 0, NULL, 'active', '2026-03-01 09:48:11', '2026-03-02 08:32:59', NULL, NULL, 'pending'),
(4, '1234567890', 'john.doe@example.com', '$2y$10$QKl21kEfCjOBEESDcTZbj.D2NIldjkr1sIsvwDVcmGhbdvXsR/BHy', 'John', 'Doe', NULL, NULL, NULL, NULL, NULL, 'BRONZE', 0, NULL, 'active', '2026-03-02 08:45:15', '2026-03-02 08:45:15', NULL, NULL, 'active');

-- --------------------------------------------------------

--
-- Table structure for table `bookings`
--

CREATE TABLE `bookings` (
  `id` int(11) NOT NULL,
  `booking_reference` varchar(50) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
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
  `status` tinyint(4) NOT NULL DEFAULT 0,
  `booking_date` date NOT NULL,
  `notes` text DEFAULT NULL,
  `user_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `bookings`
--

INSERT INTO `bookings` (`id`, `booking_reference`, `flight_series_id`, `cabin_class_id`, `passenger_id`, `passenger_name`, `passenger_email`, `passenger_phone`, `passenger_type`, `number_of_passengers`, `fare_per_passenger`, `base_fare`, `taxes_amount`, `revenue_recognized`, `total_amount`, `payment_method`, `payment_status`, `status`, `booking_date`, `notes`, `user_id`, `created_at`, `updated_at`) VALUES
(1, 'BKMINLLI7TXXPB', 1, NULL, 8, 'br', 'bryanotieno09@gmail.com', '34', 'adult', 3, 344.00, NULL, NULL, 0, 1032.00, 'cash', 'pending', 0, '2025-12-01', NULL, NULL, '2025-12-01 20:24:48', '2025-12-01 20:24:48'),
(2, 'BKMINLQV3TWH91', 1, NULL, 11, 'br', 'bryanotieno09@gmail.com', '34', 'adult', 3, 344.00, NULL, NULL, 0, 1032.00, 'cash', 'pending', 0, '2025-12-01', NULL, NULL, '2025-12-01 20:28:58', '2025-12-01 20:28:58'),
(3, 'BKMINLX1Y4NNUF', 1, NULL, 14, 'br', 'bryanotieno09@gmail.com', '34', 'adult', 3, 344.00, NULL, NULL, 0, 1032.00, 'cash', 'pending', 0, '2025-12-01', NULL, NULL, '2025-12-01 20:33:47', '2025-12-01 20:33:47'),
(4, 'BKMINM2TPOPZ1O', 1, NULL, 17, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', 'adult', 1, 344.00, NULL, NULL, 0, 344.00, 'cash', 'pending', 0, '2025-12-01', NULL, NULL, '2025-12-01 20:38:16', '2025-12-01 20:38:16'),
(5, 'BKMINMDSYOP5EK', 2, NULL, 18, 'br', 'bryanotieno09@gmail.com', '34', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2025-12-01', NULL, NULL, '2025-12-01 20:46:48', '2025-12-01 20:46:48'),
(6, 'BKMIRGQSIEQIXT', 3, NULL, 19, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', 'adult', 1, 1100.00, NULL, NULL, 0, 1100.00, 'cash', 'pending', 0, '2025-12-04', NULL, NULL, '2025-12-04 13:20:01', '2025-12-04 13:20:01'),
(7, '3485E6AACB', 1, NULL, NULL, 'Mr Be Fyy', '', '', 'adult', 1, 1030.00, NULL, NULL, 0, 1030.00, 'pending', 'pending', 0, '2025-12-04', 'Seats: 10C', NULL, '2025-12-04 13:39:36', '2025-12-04 13:39:36'),
(8, '84B80689A6', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'pending', 'pending', 0, '2025-12-05', 'Seats: ', NULL, '2025-12-05 10:56:21', '2025-12-05 10:56:21'),
(9, 'C06275EA03', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'pending', 'pending', 0, '2025-12-05', 'Seats: ', 1, '2025-12-05 11:32:59', '2025-12-07 18:07:28'),
(10, '0D36E70515', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'test', 'pending', 0, '2025-12-05', 'Test booking - Payment skipped. Seats: ', 1, '2025-12-05 11:43:26', '2025-12-05 13:24:59'),
(11, 'BKMISVXKRH6OZ0', 4, NULL, 22, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 300.00, NULL, NULL, 0, 300.00, 'cash', 'pending', 0, '2025-12-05', 'testing here', 1, '2025-12-05 13:12:58', '2025-12-05 13:24:57'),
(12, 'BKMISW0W6JH2Z6', 4, NULL, 23, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 300.00, NULL, NULL, 0, 300.00, 'cash', 'pending', 0, '2025-12-05', 'testing here', 1, '2025-12-05 13:15:32', '2025-12-05 13:24:54'),
(13, 'BKMISWPCAZ242I', 4, NULL, 24, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 300.00, NULL, NULL, 0, 300.00, 'cash', 'pending', 0, '2025-12-05', NULL, NULL, '2025-12-05 13:34:33', '2025-12-05 13:34:33'),
(14, 'BKMISWZIQL3NQ7', 4, NULL, 25, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 300.00, NULL, NULL, 0, 300.00, 'cash', 'pending', 0, '2025-12-05', NULL, NULL, '2025-12-05 13:42:28', '2025-12-05 13:42:28'),
(15, 'BKMISX4UQBU8Q8', 4, NULL, 26, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 300.00, NULL, NULL, 0, 300.00, 'cash', 'pending', 0, '2025-12-05', NULL, NULL, '2025-12-05 13:46:37', '2025-12-05 13:46:37'),
(16, 'BKMIU6WCHOOEOT', 6, NULL, 27, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 700.00, NULL, NULL, 0, 700.00, 'cash', 'pending', 0, '2025-12-06', NULL, NULL, '2025-12-06 11:07:43', '2025-12-06 11:07:43'),
(17, 'FF2C279BCA', 1, NULL, NULL, 'Mr John’s Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'test', 'pending', 0, '2025-12-07', 'Test booking - Payment skipped. Seats: ', 1, '2025-12-07 11:08:19', '2025-12-07 11:15:05'),
(18, '845271FD26', 1, NULL, NULL, 'Mr Benjamin  Okwama', '', '', 'adult', 1, 15800.00, NULL, NULL, 0, 15800.00, 'test', 'pending', 0, '2025-12-07', 'Test booking - Payment skipped. Seats: ', 1, '2025-12-07 11:21:24', '2025-12-07 11:21:24'),
(19, '72A90D9C8F', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 15800.00, NULL, NULL, 0, 15800.00, 'test', 'pending', 0, '2025-12-10', 'Test booking - Payment skipped. Seats: ', 1, '2025-12-10 12:03:26', '2025-12-10 12:03:26'),
(20, 'C973C0A032', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'mpesa', 'paid', 1, '2025-12-10', 'Seats: ', 1, '2025-12-10 12:31:31', '2025-12-11 10:37:28'),
(21, '7BA47EB57E', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'M-Pesa', 'pending', 0, '2025-12-10', 'Seats: ', 1, '2025-12-10 12:31:33', '2025-12-10 12:31:33'),
(22, '5BDCCE4189', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'mpesa', 'pending', 0, '2025-12-10', 'Seats: ', 1, '2025-12-10 14:25:35', '2025-12-10 14:25:37'),
(23, '4C4B6309F4', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'mpesa', 'pending', 0, '2025-12-10', 'Seats: ', 1, '2025-12-10 14:39:43', '2025-12-10 14:39:44'),
(24, '95DE1B56D8', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'mpesa', 'pending', 0, '2025-12-10', 'Seats: ', 1, '2025-12-10 15:02:51', '2025-12-10 15:02:53'),
(25, '0BC10F5EAE', 1, NULL, NULL, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'test', 'pending', 0, '2025-12-10', 'Test booking - Payment skipped. Seats: ', 1, '2025-12-10 15:03:17', '2025-12-10 15:03:17'),
(26, '9FA80E170A', 1, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'mpesa', 'pending', 0, '2025-12-11', 'Seats: ', 1, '2025-12-11 16:21:44', '2025-12-11 16:21:45'),
(27, '5C4AC1FC22', 1, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'test', 'pending', 0, '2025-12-11', 'Test booking - Payment skipped. Seats: ', 1, '2025-12-11 16:21:57', '2025-12-11 16:21:57'),
(29, '7AC5719381', 7, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'test', 'pending', 0, '2026-01-27', 'Test booking - Payment skipped. Seats: ', 1, '2026-01-27 11:28:16', '2026-01-27 11:28:16'),
(30, '153036A995', 8, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'Mobile Money (Onafriq)', 'pending', 0, '2026-01-27', 'Seats: ', 1, '2026-01-27 11:30:09', '2026-01-27 11:30:09'),
(31, '6505144E39', 8, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'Mobile Money (Onafriq)', 'pending', 0, '2026-01-27', 'Seats: ', 1, '2026-01-27 11:30:12', '2026-01-27 11:30:12'),
(32, 'E9B1C5B895', 8, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'Mobile Money (Onafriq)', 'pending', 0, '2026-01-27', 'Seats: ', 1, '2026-01-27 11:30:13', '2026-01-27 11:30:13'),
(33, 'B7FE9E28A5', 8, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'Mobile Money (Onafriq)', 'pending', 0, '2026-01-27', 'Seats: ', 1, '2026-01-27 11:30:14', '2026-01-27 11:30:14'),
(34, '8249A76491', 8, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'Mobile Money (Onafriq)', 'pending', 0, '2026-01-27', 'Seats: ', 1, '2026-01-27 11:30:22', '2026-01-27 11:30:22'),
(35, 'D71F837C2D', 8, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'Card (DPO)', 'pending', 0, '2026-01-27', 'Seats: ', 1, '2026-01-27 11:31:43', '2026-01-27 11:31:43'),
(36, 'A8E3ACAE38', 7, NULL, NULL, 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'Mobile Money (Onafriq)', 'pending', 0, '2026-01-27', 'Seats: ', 1, '2026-01-27 12:40:58', '2026-01-27 12:40:58'),
(37, '27C1AACD73', 21, NULL, NULL, 'Mr Benjamin Okwama', 'reviewer@mcaviation.com', '0706166875', 'adult', 1, 28000.00, NULL, NULL, 0, 28000.00, 'mpesa', 'pending', 0, '2026-01-31', 'Test booking - Payment skipped. Class: Economy. Seats: ', 1, '2026-01-31 16:00:54', '2026-02-04 12:16:38'),
(38, '2A163ADF46', 15, NULL, NULL, 'Mr Benjamin Okwama', 'reviewer@mcaviation.com', '0706166875', 'adult', 1, 18000.00, NULL, NULL, 0, 18000.00, 'test', 'pending', 0, '2026-02-11', 'Test booking - Payment skipped. Class: Economy. Seats: ', 1, '2026-02-11 13:39:06', '2026-02-11 13:39:06'),
(39, 'BKMLY6LTVUAA9D', 23, NULL, 50, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-22', NULL, NULL, '2026-02-22 20:09:44', '2026-02-22 20:09:44'),
(40, 'BKMLYVGWPBOGNG', 24, NULL, 51, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 07:45:45', '2026-02-23 07:45:45'),
(41, 'BKMLYVMXV0Y6JX', 24, NULL, 52, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 07:50:26', '2026-02-23 07:50:26'),
(42, 'BKMLYVQJDVWSVI', 24, NULL, 53, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 07:53:14', '2026-02-23 07:53:14'),
(43, 'BKMLYVU8CW35N6', 24, NULL, 54, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 07:56:06', '2026-02-23 07:56:06'),
(44, 'BKMLYVYD9J687I', 24, NULL, 55, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 07:59:20', '2026-02-23 07:59:20'),
(45, 'BKMLYVZN170F52', 24, NULL, 56, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 08:00:19', '2026-02-23 08:00:19'),
(46, 'BKMLYW3JISN5MI', 24, NULL, 57, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 08:03:21', '2026-02-23 08:03:21'),
(47, 'BKMLYWUEAW0QYT', 24, NULL, 58, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 08:24:14', '2026-02-23 08:24:14'),
(48, 'BKMLYWX2BL62FD', 24, NULL, 59, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 08:26:18', '2026-02-23 08:26:18'),
(49, 'BKMLYX61YPZ9PV', 24, NULL, 60, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', 'ess', NULL, '2026-02-23 08:33:17', '2026-02-23 08:33:17'),
(50, 'BKMLYY8SXPF3K1', 24, NULL, 61, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:03:25', '2026-02-23 09:03:25'),
(51, 'BKMLYYML52VIHG', 24, NULL, 63, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 363.64, 36.36, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:14:09', '2026-02-23 09:14:09'),
(52, 'BKMLYYO4S5ZE70', 24, NULL, 64, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 363.64, 36.36, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:15:21', '2026-02-23 09:15:21'),
(53, 'BKMLYYUJG4JYQL', 24, NULL, 65, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'child', 1, 200.00, 181.82, 18.18, 0, 200.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:20:20', '2026-02-23 09:20:20'),
(54, 'BKMLYYVTLA7Z3J', 24, NULL, 66, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'child', 1, 200.00, 181.82, 18.18, 0, 200.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:21:20', '2026-02-23 09:21:20'),
(55, 'BKMLYZ26VYQT2O', 24, NULL, 67, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 363.64, 36.36, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:26:17', '2026-02-23 09:26:17'),
(56, 'BKMLYZ3JYL173H', 24, NULL, 68, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 344.83, 55.17, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:27:20', '2026-02-23 09:27:20'),
(57, 'BKMLYZAZP8P4Y7', 24, NULL, 69, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 363.64, 36.36, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:33:07', '2026-02-23 09:33:07'),
(58, 'BKMLYZH3QDKL93', 24, NULL, 70, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'child', 1, 200.00, 181.82, 18.18, 0, 200.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:37:52', '2026-02-23 09:37:52'),
(59, 'BKMLYZH6JLVTMI', 24, NULL, 71, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'child', 1, 200.00, 181.82, 18.18, 0, 200.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:37:56', '2026-02-23 09:37:56'),
(60, 'BKMLYZJRV2GJLL', 24, NULL, 72, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 363.64, 36.36, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:39:57', '2026-02-23 09:39:57'),
(61, 'BKMLYZQ20HJZIV', 24, NULL, 73, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'child', 1, 200.00, 181.82, 18.18, 0, 200.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:44:50', '2026-02-23 09:44:50'),
(62, 'BKMLYZQLP3XQES', 24, NULL, 74, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 363.64, 36.36, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:45:15', '2026-02-23 09:45:15'),
(63, 'BKMLYZWRKD5GRH', 24, NULL, 75, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 344.83, 55.17, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:50:03', '2026-02-23 09:50:03'),
(64, 'BKMLZ091XN9UF4', 24, NULL, 76, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, 363.64, 36.36, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 09:59:36', '2026-02-23 09:59:36'),
(65, 'BKMLZ0D9R7E4QV', 24, NULL, 77, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'child', 1, 200.00, 181.82, 18.18, 0, 200.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 10:02:53', '2026-02-23 10:02:53'),
(66, 'BKMLZ0IJQXAKRG', 24, NULL, 78, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'adult', 1, 400.00, NULL, NULL, 0, 400.00, 'cash', 'pending', 0, '2026-02-23', NULL, NULL, '2026-02-23 10:07:00', '2026-02-23 10:07:00'),
(67, '9CC7C72686', 7, NULL, NULL, 'Benjamin Okwama', 'reviewer@mcaviation.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-24', NULL, 1, '2026-02-24 12:43:53', '2026-02-24 12:43:53'),
(68, '7E56BD8FCB', 8, NULL, NULL, 'Benjamin Okwama', 'reviewer@mcaviation.com', '0706166875', 'Adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'M-Pesa', 'pending', 0, '2026-02-24', NULL, 1, '2026-02-24 13:36:17', '2026-02-24 13:36:17'),
(69, '82EF701489', 8, NULL, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'M-Pesa', 'pending', 0, '2026-02-25', NULL, 1, '2026-02-25 11:12:09', '2026-02-25 11:12:09'),
(70, '97GSWM', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-26', NULL, 1, '2026-02-26 13:03:00', '2026-02-26 13:03:00'),
(71, 'GR0ACV', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-26', NULL, 1, '2026-02-26 13:03:23', '2026-02-26 13:03:23'),
(72, 'ZB86IV', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-26', NULL, 1, '2026-02-26 18:13:02', '2026-02-26 18:13:02'),
(73, 'G31KQW', 9, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 12500.00, NULL, NULL, 0, 12500.00, 'M-Pesa', 'pending', 0, '2026-02-26', NULL, 1, '2026-02-26 18:41:15', '2026-02-26 18:41:15'),
(74, 'BXC2TW', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 09:58:58', '2026-02-27 09:58:58'),
(75, 'HU61FK', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 09:59:02', '2026-02-27 09:59:02'),
(76, 'UY1ZW6', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 09:59:04', '2026-02-27 09:59:04'),
(77, '8IS0XF', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 10:08:42', '2026-02-27 10:08:42'),
(78, 'JT6AVS', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 10:21:15', '2026-02-27 10:21:15'),
(79, '0OTL21', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 8500.00, NULL, NULL, 0, 8500.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 10:30:52', '2026-02-27 10:30:52'),
(80, 'QKTS2D', 8, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 10:51:56', '2026-02-27 10:51:56'),
(81, 'J6IG3B', 8, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 9200.00, NULL, NULL, 0, 9200.00, 'Onafriq', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 10:53:13', '2026-02-27 10:53:13'),
(82, 'M9TWYO', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 850.00, NULL, NULL, 0, 850.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 11:11:50', '2026-02-27 11:11:50'),
(83, 'IO4P0U', 7, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 850.00, NULL, NULL, 0, 850.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 11:15:36', '2026-02-27 11:15:36'),
(84, 'CZKMOU', 8, 1, NULL, 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Adult', 1, 920.00, NULL, NULL, 0, 920.00, 'M-Pesa', 'pending', 0, '2026-02-27', NULL, 1, '2026-02-27 13:20:55', '2026-02-27 13:20:55');

-- --------------------------------------------------------

--
-- Table structure for table `booking_passengers`
--

CREATE TABLE `booking_passengers` (
  `id` int(11) NOT NULL,
  `booking_id` int(11) NOT NULL,
  `passenger_id` int(11) NOT NULL,
  `passenger_type` varchar(20) NOT NULL,
  `fare_amount` decimal(10,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_swedish_ci;

--
-- Dumping data for table `booking_passengers`
--

INSERT INTO `booking_passengers` (`id`, `booking_id`, `passenger_id`, `passenger_type`, `fare_amount`, `created_at`) VALUES
(1, 3, 14, 'adult', 344.00, '2025-12-01 20:33:47'),
(2, 3, 15, 'adult', 344.00, '2025-12-01 20:33:47'),
(3, 3, 16, 'adult', 344.00, '2025-12-01 20:33:48'),
(4, 4, 17, 'adult', 344.00, '2025-12-01 20:38:16'),
(5, 5, 18, 'adult', 400.00, '2025-12-01 20:46:49'),
(6, 6, 19, 'adult', 1100.00, '2025-12-04 13:20:02'),
(7, 9, 20, 'adult', 12500.00, '2025-12-05 11:33:00'),
(8, 10, 21, 'adult', 12500.00, '2025-12-05 11:43:26'),
(9, 11, 22, 'adult', 300.00, '2025-12-05 13:12:58'),
(10, 12, 23, 'adult', 300.00, '2025-12-05 13:15:33'),
(11, 13, 24, 'adult', 300.00, '2025-12-05 13:34:33'),
(12, 14, 25, 'adult', 300.00, '2025-12-05 13:42:28'),
(13, 15, 26, 'adult', 300.00, '2025-12-05 13:46:37'),
(14, 16, 27, 'adult', 700.00, '2025-12-06 11:07:43'),
(15, 17, 28, 'adult', 12500.00, '2025-12-07 11:08:19'),
(16, 18, 29, 'adult', 15800.00, '2025-12-07 11:21:24'),
(17, 19, 30, 'adult', 15800.00, '2025-12-10 12:03:26'),
(18, 20, 31, 'adult', 12500.00, '2025-12-10 12:31:31'),
(19, 21, 32, 'adult', 12500.00, '2025-12-10 12:31:33'),
(20, 22, 33, 'adult', 12500.00, '2025-12-10 14:25:35'),
(21, 23, 34, 'adult', 12500.00, '2025-12-10 14:39:43'),
(22, 24, 35, 'adult', 12500.00, '2025-12-10 15:02:51'),
(23, 25, 36, 'adult', 12500.00, '2025-12-10 15:03:17'),
(24, 26, 37, 'adult', 12500.00, '2025-12-11 16:21:44'),
(25, 27, 38, 'adult', 12500.00, '2025-12-11 16:21:57'),
(26, 29, 39, 'adult', 8500.00, '2026-01-27 11:28:16'),
(27, 30, 40, 'adult', 9200.00, '2026-01-27 11:30:09'),
(28, 31, 41, 'adult', 9200.00, '2026-01-27 11:30:12'),
(29, 32, 42, 'adult', 9200.00, '2026-01-27 11:30:13'),
(30, 33, 43, 'adult', 9200.00, '2026-01-27 11:30:14'),
(31, 34, 44, 'adult', 9200.00, '2026-01-27 11:30:22'),
(32, 35, 45, 'adult', 9200.00, '2026-01-27 11:31:43'),
(33, 36, 46, 'adult', 8500.00, '2026-01-27 12:40:58'),
(34, 37, 47, 'adult', 28000.00, '2026-01-31 16:00:54'),
(35, 38, 48, 'adult', 18000.00, '2026-02-11 13:39:06'),
(36, 39, 50, 'adult', 400.00, '2026-02-22 20:09:44'),
(37, 40, 51, 'adult', 400.00, '2026-02-23 07:45:45'),
(38, 41, 52, 'adult', 400.00, '2026-02-23 07:50:26'),
(39, 42, 53, 'adult', 400.00, '2026-02-23 07:53:14'),
(40, 43, 54, 'adult', 400.00, '2026-02-23 07:56:07'),
(41, 44, 55, 'adult', 400.00, '2026-02-23 07:59:20'),
(42, 45, 56, 'adult', 400.00, '2026-02-23 08:00:20'),
(43, 46, 57, 'adult', 400.00, '2026-02-23 08:03:21'),
(44, 47, 58, 'adult', 400.00, '2026-02-23 08:24:14'),
(45, 48, 59, 'adult', 400.00, '2026-02-23 08:26:18'),
(46, 49, 60, 'adult', 400.00, '2026-02-23 08:33:18'),
(47, 50, 61, 'adult', 400.00, '2026-02-23 09:03:26'),
(48, 51, 63, 'adult', 400.00, '2026-02-23 09:14:09'),
(49, 52, 64, 'adult', 400.00, '2026-02-23 09:15:21'),
(50, 53, 65, 'child', 200.00, '2026-02-23 09:20:20'),
(51, 54, 66, 'child', 200.00, '2026-02-23 09:21:20'),
(52, 55, 67, 'adult', 400.00, '2026-02-23 09:26:17'),
(53, 56, 68, 'adult', 400.00, '2026-02-23 09:27:21'),
(54, 57, 69, 'adult', 400.00, '2026-02-23 09:33:07'),
(55, 58, 70, 'child', 200.00, '2026-02-23 09:37:53'),
(56, 59, 71, 'child', 200.00, '2026-02-23 09:37:56'),
(57, 60, 72, 'adult', 400.00, '2026-02-23 09:39:58'),
(58, 61, 73, 'child', 200.00, '2026-02-23 09:44:50'),
(59, 62, 74, 'adult', 400.00, '2026-02-23 09:45:16'),
(60, 63, 75, 'adult', 400.00, '2026-02-23 09:50:03'),
(61, 64, 76, 'adult', 400.00, '2026-02-23 09:59:37'),
(62, 65, 77, 'child', 200.00, '2026-02-23 10:02:53'),
(63, 66, 78, 'adult', 400.00, '2026-02-23 10:07:00'),
(64, 67, 79, 'Adult', 8500.00, '2026-02-24 12:43:53'),
(65, 68, 80, 'Adult', 9200.00, '2026-02-24 13:36:17'),
(66, 69, 81, 'Adult', 9200.00, '2026-02-25 11:12:09'),
(67, 70, 82, 'Adult', 8500.00, '2026-02-26 13:03:00'),
(68, 71, 83, 'Adult', 8500.00, '2026-02-26 13:03:23'),
(69, 72, 84, 'Adult', 8500.00, '2026-02-26 18:13:02'),
(70, 73, 85, 'Adult', 12500.00, '2026-02-26 18:41:15'),
(71, 74, 86, 'Adult', 8500.00, '2026-02-27 09:58:58'),
(72, 75, 87, 'Adult', 8500.00, '2026-02-27 09:59:02'),
(73, 76, 88, 'Adult', 8500.00, '2026-02-27 09:59:04'),
(74, 77, 89, 'Adult', 8500.00, '2026-02-27 10:08:42'),
(75, 78, 90, 'Adult', 8500.00, '2026-02-27 10:21:15'),
(76, 79, 91, 'Adult', 8500.00, '2026-02-27 10:30:52'),
(77, 80, 92, 'Adult', 9200.00, '2026-02-27 10:51:56'),
(78, 81, 93, 'Adult', 9200.00, '2026-02-27 10:53:13'),
(79, 82, 94, 'Adult', 850.00, '2026-02-27 11:11:50'),
(80, 83, 95, 'Adult', 850.00, '2026-02-27 11:15:36'),
(81, 84, 96, 'Adult', 920.00, '2026-02-27 13:20:55');

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

--
-- Dumping data for table `cabin_classes`
--

INSERT INTO `cabin_classes` (`id`, `name`, `subtitle`, `base_price`, `baggage_allowance_kg`, `cabin_baggage_kg`, `priority_boarding`, `lounge_access`, `extra_legroom`, `meal_service`, `wifi_included`, `created_at`) VALUES
(1, 'Economy', 'Classic', 100.00, 20, 7, 0, 0, 0, NULL, 0, '2025-12-01 13:31:03'),
(2, 'Business', 'Premium', 500.00, 40, 15, 1, 1, 0, NULL, 0, '2025-12-01 13:31:03'),
(3, 'First', 'Luxury', 1500.00, 50, 20, 1, 1, 0, NULL, 0, '2025-12-01 13:31:03');

-- --------------------------------------------------------

--
-- Table structure for table `cargo_bookings`
--

CREATE TABLE `cargo_bookings` (
  `id` int(11) NOT NULL,
  `awb_number` varchar(20) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `shipper_name` varchar(255) NOT NULL,
  `shipper_company` varchar(255) DEFAULT NULL,
  `shipper_phone` varchar(50) NOT NULL,
  `shipper_email` varchar(255) DEFAULT NULL,
  `shipper_address` text NOT NULL,
  `consignee_name` varchar(255) NOT NULL,
  `consignee_company` varchar(255) DEFAULT NULL,
  `consignee_phone` varchar(50) NOT NULL,
  `consignee_email` varchar(255) DEFAULT NULL,
  `consignee_address` text NOT NULL,
  `commodity_type` varchar(100) NOT NULL,
  `weight_kg` decimal(10,2) NOT NULL,
  `pieces` int(11) NOT NULL DEFAULT 1,
  `volumetric_weight` decimal(10,2) DEFAULT NULL,
  `dimensions_json` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`dimensions_json`)),
  `declared_value` decimal(15,2) DEFAULT 0.00,
  `total_amount` decimal(15,2) NOT NULL,
  `currency` varchar(3) DEFAULT 'KES',
  `payment_method` varchar(50) DEFAULT 'pending',
  `payment_status` enum('pending','paid','cancelled','refunded') DEFAULT 'pending',
  `status` enum('booked','manifested','in-transit','arrived','delivered') DEFAULT 'booked',
  `notes` text DEFAULT NULL,
  `booking_date` date NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

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

--
-- Dumping data for table `Category`
--

INSERT INTO `Category` (`id`, `name`, `description`, `orderIndex`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'Boieng 737', '', 999, 1, '2025-10-30 16:00:46', '2025-11-28 14:24:10'),
(3, 'Airbus A320', '', 999, 1, '2025-10-30 16:00:46', '2025-11-28 14:24:44'),
(4, 'Airbus A380', '', 999, 1, '2025-10-30 16:00:46', '2025-11-28 14:24:59');

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

--
-- Dumping data for table `chart_of_accounts`
--

INSERT INTO `chart_of_accounts` (`id`, `account_name`, `account_code`, `account_type`, `parent_account_id`, `description`, `created_at`, `updated_at`, `is_active`) VALUES
(3, 'Fixtures and Fittings', '003000', 4, 1, '', '2025-06-15 13:19:13', '2026-02-23 08:28:16', 1),
(4, 'Land and Buildings', '004000', 4, 1, '', '2025-06-15 13:20:02', '2025-07-07 18:00:36', 1),
(5, 'Motor Vehicles', '005000', 4, 1, '', '2025-06-15 13:21:08', '2025-07-07 18:00:36', 1),
(6, 'Office equipment (inc computer equipment)\n', '006000', 4, 1, '', '2025-06-15 13:26:32', '2025-07-07 18:00:36', 1),
(7, 'Plant and Machinery', '007000', 4, 1, '', '2025-06-15 13:27:13', '2025-07-07 18:00:36', 1),
(8, 'Intangible Assets -ERP & Sales App', '008000', 5, 1, '', '2025-06-15 13:28:15', '2025-07-07 18:00:36', 1),
(9, 'Biological Assets', '009000', 5, 1, '', '2025-06-15 13:28:54', '2025-07-07 18:00:36', 1),
(10, 'Stock', '100001', 6, 1, '', '2025-06-15 13:30:13', '2025-07-07 18:00:36', 1),
(11, 'Stock Interim (Received)', '100002', 6, 1, '', '2025-06-15 13:30:59', '2025-07-07 18:00:36', 1),
(12, 'Debtors Control Account', '110000', 7, 1, ' | Last invoice: INV-3-1751913238102 | Last invoice: INV-2-1751918138904 | Last invoice: INV-3-1751996124894 | Last invoice: INV-2-1752309325399 | Last invoice: INV-2-1752320810962', '2025-06-15 13:32:13', '2025-07-07 18:00:36', 1),
(13, 'Debtors Control Account (POS)', '110001', 7, 1, '', '2025-06-15 13:33:00', '2025-07-07 18:00:36', 1),
(14, 'Other debtors', '110002', 7, 1, '', '2025-06-15 14:39:31', '2025-07-07 18:00:36', 1),
(15, 'Prepayments', '110003', 8, 1, '', '2025-06-15 14:40:01', '2025-07-07 18:00:36', 1),
(16, 'Purchase Tax Control Account', '110004', 6, 1, '', '2025-06-15 14:41:11', '2025-07-07 18:00:36', 1),
(17, 'WithHolding Tax Advance on', '110005', 6, 1, '', '2025-06-15 14:41:56', '2025-07-07 18:00:36', 1),
(18, 'Bank Suspense Account', '110006', 6, 1, '', '2025-06-15 14:42:24', '2025-07-07 18:00:36', 1),
(19, 'Outstanding Receipts', '110007', 7, 1, '', '2025-06-15 14:42:57', '2025-07-07 18:00:36', 1),
(20, 'Outstanding Payments', '110008', 6, 1, '', '2025-06-15 14:43:27', '2025-07-07 18:00:36', 1),
(21, 'DTB KES', '120001', 9, 1, '', '2025-06-15 14:44:02', '2025-07-07 18:00:36', 1),
(22, 'DTB USD', '120002', 9, 1, '', '2025-06-15 14:44:41', '2025-07-07 18:00:36', 1),
(23, 'M-pesa', '120003', 9, 1, '', '2025-06-15 14:45:07', '2025-07-07 18:00:36', 1),
(24, 'Cash', '120004', 9, 1, '', '2025-06-15 14:45:26', '2025-07-07 18:00:36', 1),
(25, 'DTB-PICTURES PAYMENTS', '120005', 9, 1, '', '2025-06-15 14:46:11', '2025-07-07 18:00:36', 1),
(26, 'ABSA', '120006', 9, 1, '', '2025-06-15 14:46:42', '2025-07-07 18:00:36', 1),
(27, 'SANLAM MMF-USD', '120007', 9, 1, '', '2025-06-15 14:47:26', '2025-07-07 18:00:36', 1),
(28, 'ABSA-USD', '120008', 9, 1, '', '2025-06-15 14:47:49', '2025-07-07 18:00:36', 1),
(29, 'ECO BANK KES', '120009', 9, 1, '', '2025-06-15 14:48:23', '2025-07-07 18:00:36', 1),
(30, 'Accounts Payables', '210000', 10, 2, '', '2025-06-15 14:50:18', '2025-07-07 18:00:36', 1),
(31, 'Other Creditors', '210002', 11, 2, '', '2025-06-15 14:50:56', '2025-07-07 18:00:36', 1),
(32, 'Accrued Liabilities', '210003', 11, 2, '', '2025-06-15 14:51:26', '2025-07-07 18:00:36', 1),
(33, 'Company Credit Card', '210004', 12, 2, '', '2025-06-15 14:51:55', '2025-07-07 18:00:36', 1),
(34, 'Bad debt provision', '210005', 11, 2, '', '2025-06-15 14:52:40', '2025-07-07 18:00:36', 1),
(35, 'Output Tax Account', '210006', 11, 0, '', '2025-06-15 14:53:12', '2025-07-07 18:00:36', 1),
(36, 'Withholding Tax Payable', '210007', 11, 2, '', '2025-06-15 14:53:51', '2025-07-07 18:00:36', 1),
(37, 'PAYE', '210008', 10, 2, '', '2025-06-15 14:54:27', '2025-07-07 18:00:36', 1),
(38, 'Net Wages', '210009', 10, 2, '', '2025-06-15 14:55:05', '2025-07-07 18:00:36', 1),
(39, 'NSSF', '210010', 10, 2, '', '2025-06-15 14:55:32', '2025-07-07 18:00:36', 1),
(40, 'NHIF', '210011', 10, 2, '', '2025-06-15 14:56:11', '2025-07-07 18:00:36', 1),
(41, 'AHL', '210012', 10, 2, '', '2025-06-15 14:56:42', '2025-07-07 18:00:36', 1),
(42, 'Due To and From Directors', '210013', 11, 2, '', '2025-06-15 14:57:16', '2025-07-07 18:00:36', 1),
(43, 'Due To and From Related Party- MSP', '210014', 11, 2, '', '2025-06-15 14:57:46', '2025-07-07 18:00:36', 1),
(44, 'Due To Other Parties', '210015', 11, 2, '', '2025-06-15 14:58:11', '2025-07-07 18:00:36', 1),
(45, 'Corporation Tax', '210016', 10, 2, '', '2025-06-15 14:58:35', '2025-07-07 18:00:36', 1),
(46, 'Wage After Tax: Accrued Liabilities', '210022', 10, 2, '', '2025-06-15 14:58:59', '2025-07-07 18:00:36', 1),
(47, 'Due To and From Related Party- GQ', '210024', 11, 2, '', '2025-06-15 14:59:52', '2025-07-07 18:00:36', 1),
(48, 'Due To and From Woosh Intl- TZ', '210034', 11, 2, '', '2025-06-15 15:00:20', '2025-07-07 18:00:36', 1),
(49, 'Share Capital', '300001', 13, 3, '', '2025-06-15 15:00:43', '2025-07-07 18:00:36', 1),
(50, 'Retained Earnings', '300002', 13, 3, '', '2025-06-15 15:01:19', '2025-07-07 18:00:36', 1),
(51, 'Other reserves', '300003', 13, 3, '', '2025-06-15 15:01:39', '2025-07-07 18:00:36', 1),
(52, 'Capital', '300004', 13, 3, '', '2025-06-15 15:01:59', '2025-07-07 18:00:36', 1),
(53, 'Passenger Revenue', '400001', 14, 4, '', '2025-06-15 15:02:21', '2026-02-23 09:03:04', 1),
(54, 'GOLD PUFF SALES', '400002', 14, 4, '', '2025-06-15 15:02:50', '2025-07-07 18:00:36', 1),
(55, 'WILD LUCY SALES', '400003', 14, 4, '', '2025-06-15 15:03:15', '2025-07-07 18:00:36', 1),
(56, 'Cash Discount Gain', '400004', 19, 0, '', '2025-06-15 15:04:54', '2025-07-07 18:00:36', 1),
(57, 'Profits/Losses on disposals of assets', '400005', 14, 4, '', '2025-06-15 15:05:26', '2025-07-07 18:00:36', 1),
(58, 'Other Income', '400006', 19, 0, '', '2025-06-15 15:05:48', '2025-07-07 18:00:36', 1),
(59, 'GOLD PUFF RECHARGEABLE SALES', '400007', 14, 4, '', '2025-06-15 15:06:13', '2025-07-07 18:00:36', 1),
(60, 'GOLD POUCH 5 DOT SALES', '400008', 14, 4, '', '2025-06-15 15:06:37', '2025-07-07 18:00:36', 1),
(61, 'GOLD POUCH 3 DOT SALES', '400009', 14, 4, '', '2025-06-15 15:07:14', '2025-07-07 18:00:36', 1),
(62, 'GOLD PUFF 3000 PUFFS RECHARGEABLE SALES', '400010', 14, 4, '', '2025-06-15 15:07:39', '2025-07-07 18:00:36', 1),
(63, 'Cost of sales ', '500000', 15, 0, '', '2025-06-15 15:08:06', '2025-07-07 18:00:36', 1),
(64, 'Cost of sales 2', '500001', 15, 5, '', '2025-06-15 15:08:26', '2025-07-07 18:00:36', 1),
(65, 'GOLD PUFF COST OF SALES', '500002', 15, 5, '', '2025-06-15 15:08:53', '2025-07-07 18:00:36', 1),
(66, 'WILD LUCY COST OF SALES', '500003', 15, 5, '', '2025-06-15 15:09:13', '2025-07-07 18:00:36', 1),
(67, 'Other costs of sales - Vapes Write Offs', '500004', 15, 5, '', '2025-06-15 15:09:36', '2025-07-07 18:00:36', 1),
(68, 'Other costs of sales', '500005', 15, 5, '', '2025-06-15 15:09:59', '2025-07-07 18:00:36', 1),
(69, 'Freight and delivery - COS E-Cigarette', '500006', 15, 5, '', '2025-06-15 15:10:25', '2025-07-07 18:00:36', 1),
(70, 'Discounts given - COS', '500007', 15, 5, '', '2025-06-15 15:10:45', '2025-07-07 18:00:36', 1),
(71, 'Direct labour - COS', '500008', 15, 5, '', '2025-06-15 15:11:07', '2025-07-07 18:00:36', 1),
(72, 'Commissions and fees', '500009', 15, 5, '', '2025-06-15 15:11:30', '2025-07-07 18:00:36', 1),
(73, 'Bar Codes/ Stickers', '500010', 15, 5, '', '2025-06-15 15:12:01', '2025-07-07 18:00:36', 1),
(74, 'GOLD PUFF RECHARGEABLE COST OF SALES', '500011', 15, 5, '', '2025-06-15 15:12:35', '2025-07-07 18:00:36', 1),
(75, 'Rebates,Price Diff & Discounts', '500012', 15, 5, '', '2025-06-15 15:12:55', '2025-07-07 18:00:36', 1),
(76, 'GOLD POUCH 5 DOT COST OF SALES', '500013', 15, 5, '', '2025-06-15 15:13:17', '2025-07-07 18:00:36', 1),
(77, 'GOLD POUCH 3 DOT COST OF SALES', '500014', 15, 5, '', '2025-06-15 15:13:38', '2025-07-07 18:00:36', 1),
(78, 'GOLD PUFF 3000 PUFFS RECHARGEABLE COST OF SALES', '500015', 15, 5, '', '2025-06-15 15:14:02', '2025-07-07 18:00:36', 1),
(79, 'Vehicle Washing', '510001', 16, 5, '', '2025-06-15 15:31:22', '2025-07-07 18:00:36', 1),
(80, 'Vehicle R&M', '510002', 16, 5, '', '2025-06-15 15:31:49', '2025-07-07 18:00:36', 1),
(81, 'Vehicle Parking Fee', '510003', 16, 5, '', '2025-06-15 15:32:15', '2025-07-07 18:00:36', 1),
(82, 'Vehicle Insurance fee', '510004', 16, 5, '', '2025-06-15 15:32:47', '2025-07-07 18:00:36', 1),
(83, 'Vehicle fuel cost', '510005', 16, 5, '', '2025-06-15 15:33:09', '2025-07-07 18:00:36', 1),
(84, 'Driver Services', '510006', 16, 5, '', '2025-06-15 15:33:35', '2025-07-07 18:00:36', 1),
(85, 'Travel expenses - selling expenses', '510007', 16, 5, '', '2025-06-15 15:34:04', '2025-07-07 18:00:36', 1),
(86, 'Travel expenses - Sales Fuel Allowance', '510008', 16, 5, '', '2025-06-15 15:34:30', '2025-07-07 18:00:36', 1),
(87, 'Travel expenses - Sales Car Lease', '510009', 16, 5, '', '2025-06-15 15:35:05', '2025-07-07 18:00:36', 1),
(88, 'Travel expenses - Other Travel Expenses', '510010', 16, 5, '', '2025-06-15 15:35:55', '2025-07-07 18:00:36', 1),
(89, 'Travel expenses- General Fuel Allowance', '510011', 16, 5, '', '2025-06-15 15:36:51', '2025-07-07 18:00:36', 1),
(90, 'Travel expenses - General Car Lease', '510012', 16, 5, '', '2025-06-15 15:37:20', '2025-07-07 18:00:36', 1),
(91, 'Travel Expense- General and admin expenses', '510013', 16, 5, '', '2025-06-15 15:37:46', '2025-07-07 18:00:36', 1),
(92, 'Mpesa handling fee', '510014', 16, 5, '', '2025-06-15 15:38:09', '2025-07-07 18:00:36', 1),
(93, 'Other Types of Expenses-Advertising Expenses', '510015', 16, 5, '', '2025-06-15 15:38:34', '2025-07-07 18:00:36', 1),
(94, 'Merchandize', '510016', 16, 5, '', '2025-06-15 15:38:58', '2025-07-07 18:00:36', 1),
(95, 'Influencer Payment', '510017', 16, 5, '', '2025-06-15 15:39:20', '2025-07-07 18:00:36', 1),
(96, 'Advertizing Online', '510018', 16, 5, '', '2025-06-15 15:39:41', '2025-07-07 18:00:36', 1),
(97, 'Trade Marketing Costs', '510019', 16, 5, '', '2025-06-15 15:40:05', '2025-07-07 18:00:36', 1),
(98, 'Aircraft Fueling', '510020', 16, 5, '', '2025-06-15 15:40:25', '2026-02-03 09:02:49', 1),
(99, 'Other selling expenses', '510021', 16, 5, '', '2025-06-15 15:40:47', '2025-07-07 18:00:36', 1),
(100, 'Other general and administrative expenses', '510022', 16, 5, '', '2025-06-15 15:41:08', '2025-07-07 18:00:36', 1),
(101, 'Rent or Lease of Apartments', '510023', 16, 5, '', '2025-06-15 15:41:30', '2025-07-07 18:00:36', 1),
(102, 'Penalty & Interest Account', '510024', 16, 5, '', '2025-06-15 15:41:58', '2025-07-07 18:00:36', 1),
(103, 'Dues and subscriptions', '510025', 16, 5, '', '2025-06-15 15:42:19', '2025-07-07 18:00:36', 1),
(104, 'Utilities (Electricity and Water)', '510026', 16, 5, '', '2025-06-15 15:42:43', '2025-07-07 18:00:36', 1),
(105, 'Telephone and postage', '510027', 16, 5, '', '2025-06-15 15:43:13', '2025-07-07 18:00:36', 1),
(106, 'Stationery and printing', '510028', 16, 5, '', '2025-06-15 15:43:33', '2025-07-07 18:00:36', 1),
(107, 'Service Fee', '510029', 16, 5, '', '2025-06-15 15:43:54', '2025-07-07 18:00:36', 1),
(108, 'Repairs and Maintenance', '510030', 16, 5, '', '2025-06-15 15:44:15', '2025-07-07 18:00:36', 1),
(109, 'Rent or lease payments', '510031', 16, 5, '', '2025-06-15 15:44:45', '2025-07-07 18:00:36', 1),
(110, 'Office Internet', '510032', 16, 5, '', '2025-06-15 15:45:05', '2025-07-07 18:00:36', 1),
(111, 'Office decoration Expense', '510033', 16, 5, '', '2025-06-15 15:45:26', '2025-07-07 18:00:36', 1),
(112, 'Office Cleaning and Sanitation', '510034', 16, 5, '', '2025-06-15 15:45:51', '2025-07-07 18:00:36', 1),
(113, 'IT Development', '510035', 16, 5, '', '2025-06-15 15:46:12', '2025-07-07 18:00:36', 1),
(114, 'Insurance - Liability', '510036', 16, 5, '', '2025-06-15 15:46:34', '2025-07-07 18:00:36', 1),
(115, 'Business license fee', '510037', 16, 5, '', '2025-06-15 15:46:58', '2025-07-07 18:00:36', 1),
(116, 'Other Legal and Professional Fees', '510038', 16, 5, '', '2025-06-15 15:47:31', '2025-07-07 18:00:36', 1),
(117, 'IT Expenses', '510039', 16, 5, '', '2025-06-15 15:47:51', '2025-07-07 18:00:36', 1),
(118, 'Recruitment fee', '510040', 16, 5, '', '2025-06-15 15:48:18', '2025-07-07 18:00:36', 1),
(119, 'Payroll Expenses(Before Tax)', '510041', 16, 5, '', '2025-06-15 15:48:44', '2025-07-07 18:00:36', 1),
(120, 'Outsourced Labor Services', '510042', 16, 5, '', '2025-06-15 15:49:07', '2025-07-07 18:00:36', 1),
(121, 'NSSF ( Company Paid)', '510043', 16, 5, '', '2025-06-15 15:49:34', '2025-07-07 18:00:36', 1),
(122, 'Employee welfare', '510044', 16, 5, '', '2025-06-15 15:49:56', '2025-07-07 18:00:36', 1),
(123, 'Bonus & Allowance', '510045', 16, 5, '', '2025-06-15 15:50:19', '2025-07-07 18:00:36', 1),
(124, 'Affordable Housing Levy (AHL)', '510046', 16, 5, '', '2025-06-15 15:50:43', '2025-07-07 18:00:36', 1),
(125, 'Income tax expense', '510047', 16, 5, '', '2025-06-15 15:51:05', '2025-07-07 18:00:36', 1),
(126, 'Team Building', '510048', 16, 5, '', '2025-06-15 15:51:28', '2025-07-07 18:00:36', 1),
(127, 'Meetings', '510049', 16, 5, '', '2025-06-15 15:51:55', '2025-07-07 18:00:36', 1),
(128, 'Meals and entertainment', '510050', 16, 5, '', '2025-06-15 15:52:20', '2025-07-07 18:00:36', 1),
(129, 'Interest expense', '510051', 16, 5, '', '2025-06-15 15:52:40', '2025-07-07 18:00:36', 1),
(130, 'Bad debts', '510052', 17, 0, '', '2025-06-15 15:53:05', '2025-07-07 18:00:36', 1),
(131, 'Bank handling fee', '510054', 16, 5, '', '2025-06-15 15:53:29', '2025-07-07 18:00:36', 1),
(132, 'Patents & Trademarks Depreciation', '520001', 17, 0, '', '2025-06-15 15:54:02', '2025-07-07 18:00:36', 1),
(133, 'Fixtures and fittings Depreciation', '520002', 16, 5, '', '2025-06-15 15:54:23', '2025-07-07 18:00:36', 1),
(134, 'Land and buildings Depreciation', '520003', 17, 0, '', '2025-06-15 15:54:45', '2025-07-07 18:00:36', 1),
(135, 'Motor vehicles Depreciation', '520004', 17, 0, '', '2025-06-15 15:55:09', '2025-07-07 18:00:36', 1),
(136, 'Office equipment (inc computer equipment) Depreciation', '520005', 17, 0, '', '2025-06-15 15:55:35', '2025-07-07 18:00:36', 1),
(137, 'Plant and machinery Depreciation', '520006', 17, 0, '', '2025-06-15 15:55:58', '2025-07-07 18:00:36', 1),
(138, 'Undistributed Profits/Losses', '999999', 18, 3, '', '2025-06-15 15:56:19', '2025-07-07 18:00:36', 1),
(139, 'Accumulated Depreciation', '520007', 17, 0, NULL, '2025-07-08 06:19:04', '2025-07-08 06:19:04', 1),
(140, 'Accounts Receivable', '1100', 7, 0, 'Amounts owed by customers for goods or services provided | Last invoice: INV-2-1752321159077 | Last invoice: INV-2-1752397570019 | Last invoice: INV-2-1752649457669', '2025-07-12 09:40:18', '2025-07-12 09:40:18', 1),
(141, 'PAYE Payable', '37', 2, 0, NULL, '2025-08-10 10:32:21', '2025-08-10 10:32:21', 1),
(142, 'Net Wages', '38', 5, 0, NULL, '2025-08-10 10:32:21', '2025-08-10 10:32:21', 1),
(143, 'NSSF Payable', '39', 2, 0, NULL, '2025-08-10 10:32:21', '2025-08-10 10:32:21', 1),
(144, 'NHIF Payable', '40', 2, 0, NULL, '2025-08-10 10:32:21', '2025-08-10 10:32:21', 1);

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
  `status` int(11) DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `Country`
--

INSERT INTO `Country` (`id`, `name`, `status`) VALUES
(1, 'Kenya', 1),
(2, 'Tanzania', 1),
(3, 'Comoros', 1),
(4, 'France', 1),
(5, 'Uganda', 1),
(6, 'Rwanda', 1),
(7, 'Democratic Republic of Congo', 1),
(8, 'Cameroon', 1),
(9, 'Gabon', 1),
(10, 'Madagascar', 1);

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

--
-- Dumping data for table `crew`
--

INSERT INTO `crew` (`id`, `name`, `contact`, `role`, `nationality`, `id_number`, `license_number`, `license_issue_date`, `medical_class`, `medical_date`, `fixed_wing_training_date`, `rotorcraft_asel`, `rotorcraft_amel`, `rotorcraft_ases`, `rotorcraft_ames`, `created_at`, `updated_at`) VALUES
(1, 'John per', '8899', 'Pilot', NULL, '890', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-04 12:34:35', '2025-12-04 12:34:35');

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

--
-- Dumping data for table `departments`
--

INSERT INTO `departments` (`id`, `name`) VALUES
(1, 'Admin'),
(2, 'Finance'),
(3, 'Reservations'),
(4, 'Operations'),
(5, 'Travel Agents');

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
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `destinations`
--

INSERT INTO `destinations` (`id`, `code`, `name`, `country_id`, `longitude`, `latitude`, `timezone`, `status`, `is_popular`, `father_code`, `destination`, `image_url`, `created_at`, `updated_at`) VALUES
(1, 'NWA', 'Moheli', 2, 36.8018412, -1.3009875, 'America/Phoenix', 'active', 0, '22', 'Moheli Bandar Es Eslam Airport (NWA)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2025-11-28 20:34:49', '2026-02-26 16:06:26'),
(5, 'MBA', 'Mombasa', 2, 36.8018412, -1.3009875, 'America/Toronto', 'active', 1, '22', 'Moi International Airport (MBA)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2025-11-29 12:10:25', '2026-02-26 16:06:26'),
(24, 'NBO', 'Nairobi', 1, 36.9258000, -1.3192000, 'Africa/Nairobi', 'active', 1, NULL, 'Jomo Kenyatta International Airport (NBO)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(25, 'DAR', 'Dar es Salaam', 2, 39.2026000, -6.8781000, 'Africa/Dar_es_Salaam', 'active', 1, NULL, 'Julius Nyerere International Airport (DAR)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(26, 'EBB', 'Entebbe', 5, 32.4435000, 0.0424000, 'Africa/Kampala', 'active', 1, NULL, 'Entebbe International Airport (EBB)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(27, 'KGL', 'Kigali', 6, 30.1395000, -1.9686000, 'Africa/Kigali', 'active', 0, NULL, 'Kigali International Airport (KGL)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(28, 'FIH', 'Kinshasa', 7, 15.4446000, -4.3857000, 'Africa/Kinshasa', 'active', 0, NULL, 'N\'djili International Airport (FIH)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(29, 'DLA', 'Douala', 8, 9.7195000, 4.0061000, 'Africa/Douala', 'active', 0, NULL, 'Douala International Airport (DLA)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(30, 'LBV', 'Libreville', 9, 9.4123000, 0.4586000, 'Africa/Libreville', 'active', 0, NULL, 'Libreville International Airport (LBV)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(31, 'HAH', 'Moroni', 3, 43.2719000, -11.5337000, 'Indian/Comoro', 'active', 0, NULL, 'Prince Said Ibrahim International Airport (HAH)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(32, 'TNR', 'Antananarivo', 10, 47.4788000, -18.7969000, 'Indian/Antananarivo', 'active', 0, NULL, 'Ivato International Airport (TNR)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-01-27 10:57:15', '2026-02-26 16:06:26'),
(33, 'BJR', 'Bahir Dar Airport', 3, 37.3216000, 11.6081000, 'Europe/Rome', 'active', 0, '887', 'Helipad', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-02-21 18:04:19', '2026-02-26 16:06:26'),
(34, 'ADJ', 'Amman Civil Airport (Marka International Airport)', 3, 35.9916000, 31.9727000, 'Europe/Rome', 'active', 0, '666', 'Moheli Bandar Es Eslam Airport (NWA)', 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg?updatedAt=1772106491541', '2026-02-21 18:05:00', '2026-02-26 16:06:26');

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

--
-- Dumping data for table `device_tokens`
--

INSERT INTO `device_tokens` (`id`, `user_id`, `device_token`, `platform`, `created_at`, `updated_at`) VALUES
(1, 1, 'bf82affd81a0276363f8b80c4521521cf3597357fbf0627cc550ab9294cd8626', 'ios', '2026-01-08 12:25:58', '2026-01-08 13:10:24'),
(8, 1, '160f1ae6bc79277cf9c705be92e256e811ade6888f732d12683f4bae6b04d48b', 'ios', '2026-01-08 13:13:10', '2026-02-24 11:07:13'),
(29, 1, 'b7a794a0cde291af96f3b12256bac884ee4e0218976d0da8157f27cb0a15506b', 'ios', '2026-01-27 22:28:00', '2026-02-19 11:09:22'),
(41, 1, '64bff9f197c0c3bd20b2c89f2372864ac5f78038eba342e29e24afde76c89e53', 'ios', '2026-02-19 11:22:15', '2026-02-25 07:38:05');

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

--
-- Dumping data for table `exchange_rates`
--

INSERT INTO `exchange_rates` (`id`, `currency_code`, `rate`, `last_updated`) VALUES
(1, 'EUR', 1.000000, '2025-12-07 15:43:26'),
(2, 'USD', 1.164546, '2025-12-07 15:58:16'),
(3, 'GBP', 0.872678, '2025-12-07 15:58:16'),
(4, 'QAR', 4.244719, '2025-12-07 15:58:16'),
(5, 'AED', 4.276798, '2025-12-07 15:58:16'),
(6, 'SAR', 4.370508, '2025-12-07 15:58:16'),
(7, 'KES', 150.636483, '2025-12-07 15:58:16'),
(8, 'JPY', 180.924237, '2025-12-07 15:58:16'),
(9, 'CNY', 8.233458, '2025-12-07 15:58:16'),
(55, 'CDF', 2703.000000, '2026-02-24 13:18:53'),
(56, 'XAF', 655.957000, '2026-02-24 13:18:53'),
(57, 'KMF', 491.968000, '2026-02-24 13:18:53');

-- --------------------------------------------------------

--
-- Table structure for table `expenses`
--

CREATE TABLE `expenses` (
  `id` int(11) NOT NULL,
  `journal_entry_id` int(11) NOT NULL,
  `supplier_id` int(11) DEFAULT NULL,
  `amount_paid` decimal(11,2) NOT NULL,
  `balance` decimal(11,2) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `expenses`
--

INSERT INTO `expenses` (`id`, `journal_entry_id`, `supplier_id`, `amount_paid`, `balance`, `created_at`) VALUES
(4, 7, NULL, 10.00, 190.00, '2026-02-02 21:39:05'),
(5, 14, 1, 50.00, 0.00, '2026-02-04 04:44:15'),
(6, 16, 1, 40.00, 0.00, '2026-02-04 04:46:08'),
(7, 17, 1, 0.00, 5.00, '2026-02-04 04:49:03');

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

--
-- Dumping data for table `experiences`
--

INSERT INTO `experiences` (`id`, `title`, `subtitle`, `icon`, `color_hex`, `is_active`, `created_at`) VALUES
(1, 'Lounge Access', 'Premium access', 'sofa.fill', '#7209B7', 1, '2026-01-08 11:25:40'),
(2, 'Tours & Activities', 'Explore more', 'map.fill', '#06D6A0', 1, '2026-01-08 11:25:40');

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

--
-- Dumping data for table `flight_crew`
--

INSERT INTO `flight_crew` (`id`, `flight_series_id`, `crew_id`, `created_at`) VALUES
(1, 1, 1, '2025-12-04 12:47:37'),
(2, 4, 1, '2025-12-05 14:06:20'),
(3, 23, 1, '2026-02-21 18:35:45'),
(4, 24, 1, '2026-02-23 07:24:19');

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
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp(),
  `status` varchar(50) DEFAULT 'Scheduled',
  `actual_std` time DEFAULT NULL,
  `actual_sta` time DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `flight_series`
--

INSERT INTO `flight_series` (`id`, `flt`, `aircraft_id`, `flight_type`, `start_date`, `end_date`, `std`, `sta`, `number_of_seats`, `from_destination_id`, `from_terminal`, `to_terminal`, `via_destination_id`, `via_std`, `via_sta`, `to_destination_id`, `adult_fare`, `child_fare`, `infant_fare`, `created_at`, `updated_at`, `status`, `actual_std`, `actual_sta`) VALUES
(1, 'a11', 7, 'From-To', '2025-12-01', '2025-12-05', '14:00:00', '12:57:00', 37, 5, NULL, NULL, NULL, NULL, NULL, 1, 344.00, 555.00, 0.00, '2025-11-29 11:57:35', '2025-12-04 12:48:23', 'Scheduled', NULL, NULL),
(2, '55', 6, 'From-Via_To', '2025-11-29', '2025-11-30', '21:47:00', '21:47:00', NULL, 5, 'terminal A', 'tt', 5, '21:45:00', '21:44:00', 1, 400.00, 400.00, 0.00, '2025-11-29 18:48:11', '2025-12-01 20:46:31', 'Scheduled', NULL, NULL),
(3, 'TEST1112', 7, 'From-To', '2025-12-04', '2025-12-04', '16:20:00', '19:18:00', 19, 1, 'terminal 1', 'terminal2', NULL, NULL, NULL, 5, 1100.00, 700.00, NULL, '2025-12-04 13:18:27', '2025-12-04 13:19:43', 'Scheduled', NULL, NULL),
(4, 'FLIGHT002', 7, 'From-To', '2025-12-05', '2025-12-05', '16:00:00', '18:52:00', 19, 1, 'terminal A', 'terminal2', NULL, NULL, NULL, 5, 300.00, NULL, NULL, '2025-12-05 12:52:27', '2025-12-05 13:01:21', 'Scheduled', NULL, NULL),
(5, 'AA11', 7, 'From-To', '2025-12-06', '2025-12-06', '14:00:00', '16:03:00', 19, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-06 11:05:14', '2025-12-06 11:05:14', 'Scheduled', NULL, NULL),
(6, 'BB112', 7, 'From-To', '2025-12-06', '2025-12-06', '14:06:00', '17:06:00', 19, 1, 'terminal A', 'terminal2', NULL, NULL, NULL, 5, 700.00, 700.00, 0.00, '2025-12-06 11:06:16', '2025-12-06 11:06:34', 'Scheduled', NULL, NULL),
(7, 'RA101', 7, 'From-To', '2026-01-27', '2026-02-26', '06:00:00', '07:15:00', 150, 24, NULL, NULL, NULL, NULL, NULL, 5, 850.00, 5500.00, 1500.00, '2026-01-27 10:57:16', '2026-02-27 10:54:33', 'Delayed', '06:45:00', NULL),
(8, 'RA103', 7, 'From-To', '2026-01-27', '2026-02-26', '14:30:00', '15:45:00', 150, 24, NULL, NULL, NULL, NULL, NULL, 5, 920.00, 6000.00, 1800.00, '2026-01-27 10:57:16', '2026-02-27 10:54:40', 'Scheduled', NULL, NULL),
(9, 'RA105', 6, 'From-To', '2026-01-27', '2026-02-26', '19:00:00', '20:15:00', 120, 24, NULL, NULL, NULL, NULL, NULL, 5, 1250.00, 8000.00, 2500.00, '2026-01-27 10:57:16', '2026-02-27 10:54:27', 'Scheduled', NULL, NULL),
(10, 'RA102', 7, 'From-To', '2026-01-27', '2026-02-26', '08:00:00', '09:15:00', 150, 5, NULL, NULL, NULL, NULL, NULL, 24, 850.00, 5500.00, 1500.00, '2026-01-27 10:57:16', '2026-02-27 10:54:46', 'Scheduled', NULL, NULL),
(11, 'RA104', 7, 'From-To', '2026-01-27', '2026-02-26', '16:00:00', '17:15:00', 150, 5, NULL, NULL, NULL, NULL, NULL, 24, 920.00, 6000.00, 1800.00, '2026-01-27 10:57:16', '2026-02-27 10:54:51', 'Scheduled', NULL, NULL),
(12, 'RA106', 6, 'From-To', '2026-01-27', '2026-02-26', '20:30:00', '21:45:00', 120, 5, NULL, NULL, NULL, NULL, NULL, 24, 1250.00, 8000.00, 2500.00, '2026-01-27 10:57:16', '2026-02-27 10:54:58', 'Scheduled', NULL, NULL),
(13, 'RA201', 7, 'From-To', '2026-01-27', '2026-02-26', '10:00:00', '11:30:00', 180, 24, NULL, NULL, NULL, NULL, NULL, 25, 1500.00, 10000.00, 3000.00, '2026-01-27 10:57:16', '2026-02-27 10:55:03', 'Scheduled', NULL, NULL),
(14, 'RA202', 7, 'From-To', '2026-01-27', '2026-02-26', '12:30:00', '14:00:00', 180, 25, NULL, NULL, NULL, NULL, NULL, 24, 1500.00, 10000.00, 3000.00, '2026-01-27 10:57:16', '2026-02-27 10:55:09', 'Scheduled', NULL, NULL),
(15, 'RA301', 6, 'From-To', '2026-01-27', '2026-02-26', '07:30:00', '09:00:00', 120, 24, NULL, NULL, NULL, NULL, NULL, 26, 1800.00, 12000.00, 3500.00, '2026-01-27 10:57:16', '2026-02-27 10:55:14', 'Scheduled', NULL, NULL),
(16, 'RA302', 6, 'From-To', '2026-01-27', '2026-02-26', '15:00:00', '16:30:00', 120, 26, NULL, NULL, NULL, NULL, NULL, 24, 1800.00, 12000.00, 3500.00, '2026-01-27 10:57:16', '2026-02-27 10:56:13', 'Scheduled', NULL, NULL),
(17, 'RA401', 7, 'From-To', '2026-01-27', '2026-02-26', '11:00:00', '13:30:00', 150, 5, NULL, NULL, NULL, NULL, NULL, 31, 220.00, 15000.00, 4000.00, '2026-01-27 10:57:16', '2026-02-27 10:56:09', 'Scheduled', NULL, NULL),
(18, 'RA402', 7, 'From-To', '2026-01-27', '2026-02-26', '14:30:00', '17:00:00', 150, 31, NULL, NULL, NULL, NULL, NULL, 5, 1000.00, 15000.00, 4000.00, '2026-01-27 10:57:16', '2026-02-27 10:56:05', 'Scheduled', NULL, NULL),
(19, 'RA501', 6, 'From-To', '2026-01-27', '2026-02-26', '09:00:00', '13:00:00', 120, 24, NULL, NULL, NULL, NULL, NULL, 28, 500.00, 25000.00, 7000.00, '2026-01-27 10:57:17', '2026-02-27 10:55:51', 'Scheduled', NULL, NULL),
(20, 'RA502', 6, 'From-To', '2026-01-27', '2026-02-26', '14:00:00', '18:00:00', 120, 28, NULL, NULL, NULL, NULL, NULL, 24, 500.00, 25000.00, 7000.00, '2026-01-27 10:57:17', '2026-02-27 10:55:45', 'Scheduled', NULL, NULL),
(21, 'RA601', 7, 'From-To', '2026-01-27', '2026-02-26', '08:00:00', '10:30:00', 150, 28, NULL, NULL, NULL, NULL, NULL, 29, 800.00, 18000.00, 5000.00, '2026-01-27 10:57:17', '2026-02-27 10:55:35', 'Scheduled', NULL, NULL),
(22, 'RA602', 7, 'From-To', '2026-01-27', '2026-02-26', '16:00:00', '18:30:00', 150, 29, NULL, NULL, NULL, NULL, NULL, 28, 800.00, 18000.00, 5000.00, '2026-01-27 10:57:17', '2026-02-27 10:55:22', 'Scheduled', NULL, NULL),
(23, 'FLIGHT002', 7, 'From-To', '2026-02-22', '2026-02-22', '07:20:00', '09:18:00', 19, 25, 'terminal A', 'terminal2', NULL, NULL, NULL, 27, 400.00, 350.00, 300.00, '2026-02-21 18:18:41', '2026-02-22 20:03:28', 'Scheduled', NULL, NULL),
(24, 'FLIGHT006', 1, 'From-To', '2026-02-23', '2026-02-23', '10:30:00', '12:30:00', 30, 24, 'terminal A', 'terminal2', NULL, NULL, NULL, 31, 400.00, 200.00, 200.00, '2026-02-23 07:20:30', '2026-02-23 07:25:02', 'Scheduled', NULL, NULL),
(25, 'FLIGHT006', 7, 'From-To', '2026-03-24', '2026-03-25', '23:20:00', '05:19:00', 19, 25, 'Terminal A', 'terminal2', NULL, NULL, NULL, 1, NULL, NULL, NULL, '2026-03-24 18:19:44', '2026-03-24 18:19:44', 'Scheduled', NULL, NULL);

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

--
-- Dumping data for table `fueling`
--

INSERT INTO `fueling` (`id`, `flight_series_id`, `supplier_id`, `fuel_quantity`, `fuel_slip_number`, `price_per_liter`, `location`, `additional_fees`, `additional_fees_explanation`, `total_amount`, `tax`, `fueling_date`, `journal_entry_id`, `created_at`, `updated_at`) VALUES
(1, 21, 1, 50.00, 'ttf', 50.00, 'here', 4.00, '', 2504.00, 0.00, '2026-02-03', 11, '2026-02-03 09:39:42', '2026-02-03 09:39:42'),
(2, 21, 1, 30.00, 's23', 3.00, 'heres', 2.00, '', 104.00, 12.00, '2026-02-03', 12, '2026-02-03 10:07:49', '2026-02-03 10:07:49'),
(3, 14, 1, 100.00, 'uuy', 10.00, 'nairobi', 5.00, 'handling fees', 1010.00, 5.00, '2026-02-03', 13, '2026-02-03 10:18:27', '2026-02-03 10:18:27');

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

--
-- Dumping data for table `hotels`
--

INSERT INTO `hotels` (`id`, `name`, `location`, `description`, `amenities`, `image_url`, `price_per_night`, `rating`, `review_count`, `booking_url`, `is_active`, `created_at`) VALUES
(1, 'Royal Palm Hotel', 'Moroni, Comoros', 'Located on the Island’s prime location of the Indian Ocean, Itsandra Beach Hotel & Resort reflecting the spirit of the archipelago. This 4 stars Hotel has charming design and elegantly appointed Rooms & Suites making you feel peace with a private beach, a Gym & Massage service . Be ready for an unforgettable culinary journey with 3 Restaurants & Bars and a friendly team to welcome you. End your stay feeling refreshed and pampered in an Urban Oasis.', NULL, 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/palm%20hotel_NEoSo8Elmx.jpg', 150.00, 4.8, 0, 'https://booking.com/royal-palm-hotel', 1, '2026-01-08 11:25:40'),
(2, 'Itsandra Beach Hotel & Resort', 'Nairobi, Kenya', NULL, NULL, 'https://ik.imagekit.io/bja2qwwdjjy/Airlogix/juan-burgos-sRQclM9FkHI-unsplash_EyhBjTEC2.jpg', 120.00, 4.5, 0, NULL, 1, '2026-01-08 11:25:40');

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

--
-- Dumping data for table `iata_codes`
--

INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(1, 'AAN', 'OMAL', 'Al Ain International Airport', NULL, 'AE', 'Abu Zaby', 24.2617000, 55.6092000, 'active', '2026-01-31 19:03:06', '2026-01-31 19:03:06'),
(2, 'AUH', 'OMAA', 'Abu Dhabi International Airport', NULL, 'AE', 'Abu Zaby', 24.4330000, 54.6511000, 'active', '2026-01-31 19:03:06', '2026-01-31 19:03:06'),
(3, 'AYM', NULL, 'Yas Island Seaplane Base', NULL, 'AE', 'Abu Zaby', 24.4670000, 54.6103000, 'active', '2026-01-31 19:03:07', '2026-01-31 19:03:07'),
(4, 'AZI', 'OMAD', 'Al Bateen Executive Airport', NULL, 'AE', 'Abu Zaby', 24.4283000, 54.4581000, 'active', '2026-01-31 19:03:08', '2026-01-31 19:03:08'),
(5, 'DHF', 'OMAM', 'Al Dhafra Air Base', NULL, 'AE', 'Abu Zaby', 24.2482000, 54.5477000, 'active', '2026-01-31 19:03:08', '2026-01-31 19:03:08'),
(6, 'XSB', 'OMBY', 'Sir Bani Yas Airport', NULL, 'AE', 'Abu Zaby', 24.2836000, 52.5803000, 'active', '2026-01-31 19:03:09', '2026-01-31 19:03:09'),
(7, 'ZDY', 'OMDL', 'Dalma Airport', NULL, 'AE', 'Abu Zaby', 24.5100000, 52.3352000, 'active', '2026-01-31 19:03:10', '2026-01-31 19:03:10'),
(8, 'FJR', 'OMFJ', 'Fujairah International Airport', NULL, 'AE', 'Al Fujayrah', 25.1122000, 56.3240000, 'active', '2026-01-31 19:03:10', '2026-01-31 19:03:10'),
(9, 'SHJ', 'OMSJ', 'Sharjah International Airport', NULL, 'AE', 'Ash Shariqah', 25.3286000, 55.5172000, 'active', '2026-01-31 19:03:11', '2026-01-31 19:03:11'),
(10, 'DCG', NULL, 'Dubai Creek Seaplane Base', NULL, 'AE', 'Dubayy', 25.2422000, 55.3314000, 'active', '2026-01-31 19:03:12', '2026-01-31 19:03:12'),
(11, 'DJH', NULL, 'Jebel Ali Seaplane Base', NULL, 'AE', 'Dubayy', 24.9890000, 55.0238000, 'active', '2026-01-31 19:03:12', '2026-01-31 19:03:12'),
(12, 'DWC', 'OMDW', 'Al Maktoum International Airport', NULL, 'AE', 'Dubayy', 24.8964000, 55.1614000, 'active', '2026-01-31 19:03:13', '2026-01-31 19:03:13'),
(13, 'DXB', 'OMDB', 'Dubai International Airport', NULL, 'AE', 'Dubayy', 25.2528000, 55.3644000, 'active', '2026-01-31 19:03:13', '2026-01-31 19:03:13'),
(14, 'NHD', 'OMDM', 'Al Minhad Air Base', NULL, 'AE', 'Dubayy', 25.0268000, 55.3662000, 'active', '2026-01-31 19:03:14', '2026-01-31 19:03:14'),
(15, 'RHR', NULL, 'Al Hamra Seaplane Base', NULL, 'AE', 'Ra\'s al Khaymah', 25.6910000, 55.7780000, 'active', '2026-01-31 19:03:14', '2026-01-31 19:03:14'),
(16, 'RKT', 'OMRK', 'Ras Al Khaimah International Airport', NULL, 'AE', 'Ra\'s al Khaymah', 25.6135000, 55.9388000, 'active', '2026-01-31 19:03:15', '2026-01-31 19:03:15'),
(17, 'DAZ', 'OADZ', 'Darwaz Airport', NULL, 'AF', 'Badakhshan', 38.4611000, 70.8825000, 'active', '2026-01-31 19:03:16', '2026-01-31 19:03:16'),
(18, 'FBD', 'OAFZ', 'Fayzabad Airport', NULL, 'AF', 'Badakhshan', 37.1211000, 70.5181000, 'active', '2026-01-31 19:03:16', '2026-01-31 19:03:16'),
(19, 'KUR', 'OARZ', 'Razer Airport', NULL, 'AF', 'Badakhshan', 37.7520000, -89.0154000, 'active', '2026-01-31 19:03:17', '2026-01-31 19:03:17'),
(20, 'KWH', 'OAHN', 'Khwahan Airport', NULL, 'AF', 'Badakhshan', 37.8830000, 70.2170000, 'active', '2026-01-31 19:03:18', '2026-01-31 19:03:18'),
(21, 'SGA', 'OASN', 'Sheghnan Airport', NULL, 'AF', 'Badakhshan', 37.5670000, 71.5000000, 'active', '2026-01-31 19:03:18', '2026-01-31 19:03:18'),
(22, 'LQN', 'OAQN', 'Qala i Naw Airport', NULL, 'AF', 'Badghis', 34.9850000, 63.1178000, 'active', '2026-01-31 19:03:18', '2026-01-31 19:03:18'),
(23, 'MZR', 'OAMS', 'Mazar-e Sharif International Airport', NULL, 'AF', 'Balkh', 36.7069000, 67.2097000, 'active', '2026-01-31 19:03:19', '2026-01-31 19:03:19'),
(24, 'BIN', 'OABN', 'Bamyan Airport', NULL, 'AF', 'Bamyan', 34.8170000, 67.8170000, 'active', '2026-01-31 19:03:20', '2026-01-31 19:03:20'),
(25, 'FAH', 'OAFR', 'Farah Airport', NULL, 'AF', 'Farah', 32.3670000, 62.1830000, 'active', '2026-01-31 19:03:20', '2026-01-31 19:03:20'),
(26, 'MMZ', 'OAMN', 'Maymana Airport', NULL, 'AF', 'Faryab', 35.9308000, 64.7609000, 'active', '2026-01-31 19:03:21', '2026-01-31 19:03:21'),
(27, 'GZI', 'OAGN', 'Ghazni Airport', NULL, 'AF', 'Ghazni', 33.5312000, 68.4129000, 'active', '2026-01-31 19:03:22', '2026-01-31 19:03:22'),
(28, 'SBF', 'OADS', 'Sardeh Band Airport', NULL, 'AF', 'Ghazni', 33.3207000, 68.6365000, 'active', '2026-01-31 19:03:22', '2026-01-31 19:03:22'),
(29, 'CCN', 'OACC', 'Chaghcharan Airport', NULL, 'AF', 'Ghor', 34.5265000, 65.2710000, 'active', '2026-01-31 19:03:23', '2026-01-31 19:03:23'),
(30, 'BST', 'OABT', 'Bost Airport', NULL, 'AF', 'Helmand', 31.5597000, 64.3650000, 'active', '2026-01-31 19:03:23', '2026-01-31 19:03:23'),
(31, 'DWR', 'OADY', 'Dwyer Airport', NULL, 'AF', 'Helmand', 31.0000000, 64.0000000, 'active', '2026-01-31 19:03:24', '2026-01-31 19:03:24'),
(32, 'OAZ', 'OAZI', 'Camp Bastion Air Base', NULL, 'AF', 'Helmand', 31.8638000, 64.2246000, 'active', '2026-01-31 19:03:24', '2026-01-31 19:03:24'),
(33, 'HEA', 'OAHR', 'Herat International Airport', NULL, 'AF', 'Herat', 34.2100000, 62.2283000, 'active', '2026-01-31 19:03:25', '2026-01-31 19:03:25'),
(34, 'OAH', 'OASD', 'Shindand Air Base', NULL, 'AF', 'Herat', 33.3913000, 62.2610000, 'active', '2026-01-31 19:03:25', '2026-01-31 19:03:25'),
(35, 'ZAJ', 'OAZJ', 'Zaranj Airport', NULL, 'AF', 'Herat', 30.9722000, 61.8658000, 'active', '2026-01-31 19:03:26', '2026-01-31 19:03:26'),
(36, 'GRG', 'OAGZ', 'Gardez Airport', NULL, 'AF', 'Kabul', 33.6315000, 69.2394000, 'active', '2026-01-31 19:03:26', '2026-01-31 19:03:26'),
(37, 'KBL', 'OAKB', 'Kabul International Airport', NULL, 'AF', 'Kabul', 34.5658000, 69.2131000, 'active', '2026-01-31 19:03:27', '2026-01-31 19:03:27'),
(38, 'KDH', 'OAKN', 'Kandahar International Airport', NULL, 'AF', 'Kandahar', 31.5058000, 65.8478000, 'active', '2026-01-31 19:03:28', '2026-01-31 19:03:28'),
(39, 'TII', 'OATN', 'Tarinkot Airport', NULL, 'AF', 'Kandahar', 32.6042000, 65.8658000, 'active', '2026-01-31 19:03:28', '2026-01-31 19:03:28'),
(40, 'URZ', 'OARG', 'Uruzgan Airport', NULL, 'AF', 'Kandahar', 32.9030000, 66.6309000, 'active', '2026-01-31 19:03:29', '2026-01-31 19:03:29'),
(41, 'KHT', 'OAKS', 'Khost Airfield', NULL, 'AF', 'Khost', 33.3334000, 69.9520000, 'active', '2026-01-31 19:03:29', '2026-01-31 19:03:29'),
(42, 'OLR', 'OASL', 'Forward Operating Base Salerno', NULL, 'AF', 'Khost', 33.3638000, 69.9561000, 'active', '2026-01-31 19:03:30', '2026-01-31 19:03:30'),
(43, 'UND', 'OAUZ', 'Kunduz Airport', NULL, 'AF', 'Kunduz', 36.6651000, 68.9108000, 'active', '2026-01-31 19:03:30', '2026-01-31 19:03:30'),
(44, 'OAA', 'OASH', 'Forward Operating Base Shank', NULL, 'AF', 'Logar', 33.9225000, 69.0772000, 'active', '2026-01-31 19:03:31', '2026-01-31 19:03:31'),
(45, 'JAA', 'OAJL', 'Jalalabad Airport', NULL, 'AF', 'Nangarhar', 34.3998000, 70.4986000, 'active', '2026-01-31 19:03:31', '2026-01-31 19:03:31'),
(46, 'OAS', 'OASA', 'Sharana Airstrip / Forward Operating Base Sharana', NULL, 'AF', 'Paktika', 33.1258000, 68.8385000, 'active', '2026-01-31 19:03:32', '2026-01-31 19:03:32'),
(47, 'URN', 'OAOG', 'Urgun Airport', NULL, 'AF', 'Paktika', 32.9318000, 69.1563000, 'active', '2026-01-31 19:03:33', '2026-01-31 19:03:33'),
(48, 'OAI', 'OAIX', 'Bagram Airfield', NULL, 'AF', 'Parwan', 34.9461000, 69.2650000, 'active', '2026-01-31 19:03:33', '2026-01-31 19:03:33'),
(49, 'TQN', 'OATQ', 'Taloqan Airport', NULL, 'AF', 'Takhar', 36.7707000, 69.5320000, 'active', '2026-01-31 19:03:34', '2026-01-31 19:03:34'),
(50, 'BBQ', 'TAPH', 'Barbuda Codrington Airport', NULL, 'AG', 'Barbuda', 17.6358000, -61.8286000, 'active', '2026-01-31 19:03:34', '2026-01-31 19:03:34'),
(51, 'ANU', 'TAPA', 'V. C. Bird International Airport', NULL, 'AG', 'Saint George', 17.1367000, -61.7927000, 'active', '2026-01-31 19:03:34', '2026-01-31 19:03:34'),
(52, 'AXA', 'TQPF', 'Clayton J. Lloyd International Airport', NULL, 'AI', 'Anguilla', 18.2048000, -63.0551000, 'active', '2026-01-31 19:03:35', '2026-01-31 19:03:35'),
(53, 'TIA', 'LATI', 'Tirana International Airport', NULL, 'AL', 'Tirana', 41.4147000, 19.7206000, 'active', '2026-01-31 19:03:35', '2026-01-31 19:03:35'),
(54, 'EVN', 'UDYZ', 'Zvartnots International Airport', NULL, 'AM', 'Erevan', 40.1473000, 44.3959000, 'active', '2026-01-31 19:03:36', '2026-01-31 19:03:36'),
(55, 'LWN', 'UDSG', 'Gyumri Shirak Airport', NULL, 'AM', 'Sirak', 40.7504000, 43.8593000, 'active', '2026-01-31 19:03:36', '2026-01-31 19:03:36'),
(56, 'AZZ', 'FNAM', 'Ambriz Airport', NULL, 'AO', 'Bengo', -7.8622200, 13.1161000, 'active', '2026-01-31 19:03:37', '2026-01-31 19:03:37'),
(57, 'NBJ', 'FNBJ', 'Luanda Dr. Antonio Agostinho Neto Angola International Airport', NULL, 'AO', 'Bengo', -9.0491000, 13.5000000, 'active', '2026-01-31 19:03:37', '2026-01-31 19:03:37'),
(58, 'BUG', 'FNBG', 'Benguela Airport (Gen. V. Deslandes Airport)', NULL, 'AO', 'Benguela', -12.6090000, 13.4037000, 'active', '2026-01-31 19:03:38', '2026-01-31 19:03:38'),
(59, 'CBT', 'FNCT', 'Catumbela Airport', NULL, 'AO', 'Benguela', -12.4792000, 13.4869000, 'active', '2026-01-31 19:03:38', '2026-01-31 19:03:38'),
(60, 'LLT', 'FNLB', 'Lobito Airport', NULL, 'AO', 'Benguela', -12.3757000, 13.5610000, 'active', '2026-01-31 19:03:38', '2026-01-31 19:03:38'),
(61, 'ANL', NULL, 'Andulo Airport', NULL, 'AO', 'Bie', -11.4723000, 16.7109000, 'active', '2026-01-31 19:03:39', '2026-01-31 19:03:39'),
(62, 'SVP', 'FNKU', 'Kuito Airport', NULL, 'AO', 'Bie', -12.4046000, 16.9474000, 'active', '2026-01-31 19:03:39', '2026-01-31 19:03:39'),
(63, 'CAB', 'FNCA', 'Cabinda Airport', NULL, 'AO', 'Cabinda', -5.5969900, 12.1884000, 'active', '2026-01-31 19:03:40', '2026-01-31 19:03:40'),
(64, 'VPE', 'FNGI', 'Ondjiva Pereira Airport', NULL, 'AO', 'Cunene', -17.0435000, 15.6838000, 'active', '2026-01-31 19:03:41', '2026-01-31 19:03:41'),
(65, 'XGN', 'FNXA', 'Xangongo Airport', NULL, 'AO', 'Cunene', -16.7554000, 14.9653000, 'active', '2026-01-31 19:03:41', '2026-01-31 19:03:41'),
(66, 'NOV', 'FNHU', 'Albano Machado Airport', NULL, 'AO', 'Huambo', -12.8089000, 15.7605000, 'active', '2026-01-31 19:03:41', '2026-01-31 19:03:41'),
(67, 'JMB', NULL, 'Jamba Airport', NULL, 'AO', 'Huila', -14.6982000, 16.0701000, 'active', '2026-01-31 19:03:42', '2026-01-31 19:03:42'),
(68, 'SDD', 'FNUB', 'Lubango Mukanka Airport', NULL, 'AO', 'Huila', -14.9247000, 13.5750000, 'active', '2026-01-31 19:03:42', '2026-01-31 19:03:42'),
(69, 'CTI', 'FNCV', 'Cuito Cuanavale Airport', NULL, 'AO', 'Kuando Kubango', -15.1603000, 19.1561000, 'active', '2026-01-31 19:03:43', '2026-01-31 19:03:43'),
(70, 'DRC', NULL, 'Dirico Airport', NULL, 'AO', 'Kuando Kubango', -17.9819000, 20.7681000, 'active', '2026-01-31 19:03:43', '2026-01-31 19:03:43'),
(71, 'SPP', 'FNME', 'Menongue Airport', NULL, 'AO', 'Kuando Kubango', -14.6576000, 17.7198000, 'active', '2026-01-31 19:03:44', '2026-01-31 19:03:44'),
(72, 'NDF', NULL, 'N\'dalatando Airport', NULL, 'AO', 'Kwanza Norte', -9.2751900, 14.9772000, 'active', '2026-01-31 19:03:44', '2026-01-31 19:03:44'),
(73, 'CEO', 'FNWK', 'Waco Kungo Airport', NULL, 'AO', 'Kwanza Sul', -11.4264000, 15.1014000, 'active', '2026-01-31 19:03:45', '2026-01-31 19:03:45'),
(74, 'NDD', 'FNSU', 'Sumbe Airport', NULL, 'AO', 'Kwanza Sul', -11.1679000, 13.8475000, 'active', '2026-01-31 19:03:45', '2026-01-31 19:03:45'),
(75, 'PBN', 'FNPA', 'Porto Amboim Airport', NULL, 'AO', 'Kwanza Sul', -10.7220000, 13.7655000, 'active', '2026-01-31 19:03:46', '2026-01-31 19:03:46'),
(76, 'LAD', 'FNLU', 'Quatro de Fevereiro Airport', NULL, 'AO', 'Luanda', -8.8583700, 13.2312000, 'active', '2026-01-31 19:03:46', '2026-01-31 19:03:46'),
(77, 'CFF', 'FNCF', 'Cafunfo Airport', NULL, 'AO', 'Lunda Norte', -8.7836100, 17.9897000, 'active', '2026-01-31 19:03:46', '2026-01-31 19:03:46'),
(78, 'DUE', 'FNDU', 'Dundo Airport', NULL, 'AO', 'Lunda Norte', -7.4008900, 20.8185000, 'active', '2026-01-31 19:03:47', '2026-01-31 19:03:47'),
(79, 'LBZ', 'FNLK', 'Lucapa Airport', NULL, 'AO', 'Lunda Norte', -8.4457300, 20.7321000, 'active', '2026-01-31 19:03:48', '2026-01-31 19:03:48'),
(80, 'LZM', 'FNLZ', 'Cuango-Luzamba Airport', NULL, 'AO', 'Lunda Norte', -9.1159600, 18.0493000, 'active', '2026-01-31 19:03:48', '2026-01-31 19:03:48'),
(81, 'NZA', 'FNZG', 'Nzagi Airport', NULL, 'AO', 'Lunda Norte', -7.7169400, 21.3582000, 'active', '2026-01-31 19:03:49', '2026-01-31 19:03:49'),
(82, 'PGI', 'FNCH', 'Chitato Airport', NULL, 'AO', 'Lunda Norte', -7.3588900, 20.8047000, 'active', '2026-01-31 19:03:49', '2026-01-31 19:03:49'),
(83, 'VHC', 'FNSA', 'Henrique de Carvalho Airport', NULL, 'AO', 'Lunda Sul', -9.6890700, 20.4319000, 'active', '2026-01-31 19:03:49', '2026-01-31 19:03:49'),
(84, 'KNP', 'FNCP', 'Kapanda Airport', NULL, 'AO', 'Malange', -9.7693700, 15.4553000, 'active', '2026-01-31 19:03:50', '2026-01-31 19:03:50'),
(85, 'MEG', 'FNMA', 'Malanje Airport', NULL, 'AO', 'Malange', -9.5250900, 16.3124000, 'active', '2026-01-31 19:03:50', '2026-01-31 19:03:50'),
(86, 'CAV', 'FNCZ', 'Cazombo Airport', NULL, 'AO', 'Moxico', -11.8931000, 22.9164000, 'active', '2026-01-31 19:03:51', '2026-01-31 19:03:51'),
(87, 'CNZ', NULL, 'Cangamba Airport', NULL, 'AO', 'Moxico', -13.7106000, 19.8611000, 'active', '2026-01-31 19:03:51', '2026-01-31 19:03:51'),
(88, 'GGC', NULL, 'Lumbala N\'guimbo Airport', NULL, 'AO', 'Moxico', -14.1050000, 21.4500000, 'active', '2026-01-31 19:03:52', '2026-01-31 19:03:52'),
(89, 'LUO', 'FNUE', 'Luena Airport', NULL, 'AO', 'Moxico', -11.7681000, 19.8977000, 'active', '2026-01-31 19:03:52', '2026-01-31 19:03:52'),
(90, 'UAL', 'FNUA', 'Luau Airport', NULL, 'AO', 'Moxico', -10.7158000, 22.2311000, 'active', '2026-01-31 19:03:53', '2026-01-31 19:03:53'),
(91, 'MSZ', 'FNMO', 'Namibe Airport (Yuri Gagarin Airport)', NULL, 'AO', 'Namibe', -15.2612000, 12.1468000, 'active', '2026-01-31 19:03:53', '2026-01-31 19:03:53'),
(92, 'GXG', 'FNNG', 'Negage Airport', NULL, 'AO', 'Uige', -7.7545100, 15.2877000, 'active', '2026-01-31 19:03:54', '2026-01-31 19:03:54'),
(93, 'UGO', 'FNUG', 'Uige Airport', NULL, 'AO', 'Uige', -7.6030700, 15.0278000, 'active', '2026-01-31 19:03:54', '2026-01-31 19:03:54'),
(94, 'ARZ', 'FNZE', 'N\'zeto Airport', NULL, 'AO', 'Zaire', -7.2594400, 12.8631000, 'active', '2026-01-31 19:03:54', '2026-01-31 19:03:54'),
(95, 'SSY', 'FNBC', 'Mbanza Congo Airport', NULL, 'AO', 'Zaire', -6.2699000, 14.2470000, 'active', '2026-01-31 19:03:55', '2026-01-31 19:03:55'),
(96, 'SZA', 'FNSO', 'Soyo Airport', NULL, 'AO', 'Zaire', -6.1410900, 12.3718000, 'active', '2026-01-31 19:03:55', '2026-01-31 19:03:55'),
(97, 'TNM', 'SCRM', 'Teniente R. Marsh Airport', NULL, 'AQ', 'Antarctica', -62.1908000, -58.9867000, 'active', '2026-01-31 19:03:56', '2026-01-31 19:03:56'),
(98, 'AEP', 'SABE', 'Aeroparque Internacional Jorge Newbery', NULL, 'AR', 'Buenos Aires', -34.5589000, -58.4164000, 'active', '2026-01-31 19:03:56', '2026-01-31 19:03:56'),
(99, 'BHI', 'SAZB', 'Comandante Espora Airport', NULL, 'AR', 'Buenos Aires', -38.7250000, -62.1693000, 'active', '2026-01-31 19:03:57', '2026-01-31 19:03:57'),
(100, 'CPG', NULL, 'Carmen de Patagones Airport', NULL, 'AR', 'Buenos Aires', -40.7781000, -62.9803000, 'active', '2026-01-31 19:03:57', '2026-01-31 19:03:57'),
(101, 'CSZ', 'SAZC', 'Brigadier Hector Eduardo Ruiz Airport', NULL, 'AR', 'Buenos Aires', -37.4461000, -61.8893000, 'active', '2026-01-31 19:03:58', '2026-01-31 19:03:58'),
(102, 'EPA', 'SADP', 'El Palomar Airport', NULL, 'AR', 'Buenos Aires', -34.6099000, -58.6126000, 'active', '2026-01-31 19:03:58', '2026-01-31 19:03:58'),
(103, 'EZE', 'SAEZ', 'Ministro Pistarini International Airport', NULL, 'AR', 'Buenos Aires', -34.8222000, -58.5358000, 'active', '2026-01-31 19:03:58', '2026-01-31 19:03:58'),
(104, 'JNI', 'SAAJ', 'Junin Airport', NULL, 'AR', 'Buenos Aires', -34.5459000, -60.9306000, 'active', '2026-01-31 19:03:59', '2026-01-31 19:03:59'),
(105, 'LPG', 'SADL', 'La Plata Airport', NULL, 'AR', 'Buenos Aires', -34.9722000, -57.8947000, 'active', '2026-01-31 19:03:59', '2026-01-31 19:03:59'),
(106, 'MDQ', 'SAZM', 'Astor Piazzolla International Airport', NULL, 'AR', 'Buenos Aires', -37.9342000, -57.5733000, 'active', '2026-01-31 19:04:00', '2026-01-31 19:04:00'),
(107, 'MJR', NULL, 'Miramar Airport', NULL, 'AR', 'Buenos Aires', -38.2271000, -57.8697000, 'active', '2026-01-31 19:04:01', '2026-01-31 19:04:01'),
(108, 'NEC', 'SAZO', 'Necochea Airport', NULL, 'AR', 'Buenos Aires', -38.4831000, -58.8172000, 'active', '2026-01-31 19:04:01', '2026-01-31 19:04:01'),
(109, 'OVR', 'SAZF', 'Olavarria Airport', NULL, 'AR', 'Buenos Aires', -36.8900000, -60.2166000, 'active', '2026-01-31 19:04:02', '2026-01-31 19:04:02'),
(110, 'OYO', 'SAZH', 'Tres Arroyos Airport', NULL, 'AR', 'Buenos Aires', -38.3869000, -60.3297000, 'active', '2026-01-31 19:04:02', '2026-01-31 19:04:02'),
(111, 'PEH', 'SAZP', 'Comodoro Pedro Zanni Airport', NULL, 'AR', 'Buenos Aires', -35.8446000, -61.8576000, 'active', '2026-01-31 19:04:02', '2026-01-31 19:04:02'),
(112, 'SST', 'SAZL', 'Santa Teresita Airport', NULL, 'AR', 'Buenos Aires', -36.5423000, -56.7218000, 'active', '2026-01-31 19:04:03', '2026-01-31 19:04:03'),
(113, 'TDL', 'SAZT', 'Tandil Airport', NULL, 'AR', 'Buenos Aires', -37.2374000, -59.2279000, 'active', '2026-01-31 19:04:03', '2026-01-31 19:04:03'),
(114, 'VGS', NULL, 'General Villegas Airport', NULL, 'AR', 'Buenos Aires', -35.0000000, -63.0000000, 'active', '2026-01-31 19:04:04', '2026-01-31 19:04:04'),
(115, 'VLG', 'SAZV', 'Villa Gesell Airport', NULL, 'AR', 'Buenos Aires', -37.2354000, -57.0292000, 'active', '2026-01-31 19:04:05', '2026-01-31 19:04:05'),
(116, 'CTC', 'SANC', 'Coronel Felipe Varela International Airport', NULL, 'AR', 'Catamarca', -28.5956000, -65.7517000, 'active', '2026-01-31 19:04:05', '2026-01-31 19:04:05'),
(117, 'CNT', NULL, 'Charata Airport', NULL, 'AR', 'Chaco', -27.2164000, -61.2103000, 'active', '2026-01-31 19:04:06', '2026-01-31 19:04:06'),
(118, 'PRQ', 'SARS', 'Presidencia Roque Saenz Pena Airport', NULL, 'AR', 'Chaco', -26.7536000, -60.4922000, 'active', '2026-01-31 19:04:08', '2026-01-31 19:04:08'),
(119, 'RES', 'SARE', 'Resistencia International Airport', NULL, 'AR', 'Chaco', -27.4500000, -59.0561000, 'active', '2026-01-31 19:04:08', '2026-01-31 19:04:08'),
(120, 'ARR', 'SAVR', 'Alto Rio Senguer Airport', NULL, 'AR', 'Chubut', -45.0136000, -70.8122000, 'active', '2026-01-31 19:04:09', '2026-01-31 19:04:09'),
(121, 'CRD', 'SAVC', 'General Enrique Mosconi International Airport', NULL, 'AR', 'Chubut', -45.7853000, -67.4655000, 'active', '2026-01-31 19:04:09', '2026-01-31 19:04:09'),
(122, 'EMX', 'SAVD', 'El Maiten Airport', NULL, 'AR', 'Chubut', -42.0292000, -71.1725000, 'active', '2026-01-31 19:04:10', '2026-01-31 19:04:10'),
(123, 'EQS', 'SAVE', 'Esquel Airport', NULL, 'AR', 'Chubut', -42.9080000, -71.1395000, 'active', '2026-01-31 19:04:10', '2026-01-31 19:04:10'),
(124, 'JSM', 'SAWS', 'Jose de San Martin Airport', NULL, 'AR', 'Chubut', -44.0486000, -70.4589000, 'active', '2026-01-31 19:04:11', '2026-01-31 19:04:11'),
(125, 'OLN', 'SAVM', 'Lago Musters Airport', NULL, 'AR', 'Chubut', -45.5824000, -68.9998000, 'active', '2026-01-31 19:04:11', '2026-01-31 19:04:11'),
(126, 'PMY', 'SAVY', 'El Tehuelche Airport', NULL, 'AR', 'Chubut', -42.7592000, -65.1027000, 'active', '2026-01-31 19:04:12', '2026-01-31 19:04:12'),
(127, 'REL', 'SAVT', 'Almirante Marcos A. Zar Airport', NULL, 'AR', 'Chubut', -43.2105000, -65.2703000, 'active', '2026-01-31 19:04:12', '2026-01-31 19:04:12'),
(128, 'ROY', 'SAWM', 'Rio Mayo Airport', NULL, 'AR', 'Chubut', -45.7039000, -70.2456000, 'active', '2026-01-31 19:04:13', '2026-01-31 19:04:13'),
(129, 'COR', 'SACO', 'Ingeniero Aeronautico Ambrosio L.V. Taravella International Airport (Pajas Blancas)', NULL, 'AR', 'Cordoba', -31.3236000, -64.2080000, 'active', '2026-01-31 19:04:13', '2026-01-31 19:04:13'),
(130, 'LCM', 'SACC', 'La Cumbre Airport', NULL, 'AR', 'Cordoba', -31.0058000, -64.5319000, 'active', '2026-01-31 19:04:14', '2026-01-31 19:04:14'),
(131, 'RCU', 'SAOC', 'Las Higueras Airport', NULL, 'AR', 'Cordoba', -33.0851000, -64.2613000, 'active', '2026-01-31 19:04:14', '2026-01-31 19:04:14'),
(132, 'VDR', 'SAOD', 'Villa Dolores Airport', NULL, 'AR', 'Cordoba', -31.9452000, -65.1463000, 'active', '2026-01-31 19:04:15', '2026-01-31 19:04:15'),
(133, 'AOL', 'SARL', 'Paso de los Libres Airport', NULL, 'AR', 'Corrientes', -29.6894000, -57.1521000, 'active', '2026-01-31 19:04:15', '2026-01-31 19:04:15'),
(134, 'CNQ', 'SARC', 'Doctor Fernando Piragine Niveyro International Airport', NULL, 'AR', 'Corrientes', -27.4455000, -58.7619000, 'active', '2026-01-31 19:04:16', '2026-01-31 19:04:16'),
(135, 'MCS', 'SARM', 'Monte Caseros Airport', NULL, 'AR', 'Corrientes', -30.2719000, -57.6402000, 'active', '2026-01-31 19:04:16', '2026-01-31 19:04:16'),
(136, 'MDX', 'SATM', 'Mercedes Airport', NULL, 'AR', 'Corrientes', -29.2214000, -58.0878000, 'active', '2026-01-31 19:04:17', '2026-01-31 19:04:17'),
(137, 'OYA', 'SATG', 'Goya Airport', NULL, 'AR', 'Corrientes', -29.1058000, -59.2189000, 'active', '2026-01-31 19:04:17', '2026-01-31 19:04:17'),
(138, 'UZU', 'SATU', 'Curuzu Cuatia Airport', NULL, 'AR', 'Corrientes', -29.7706000, -57.9789000, 'active', '2026-01-31 19:04:18', '2026-01-31 19:04:18'),
(139, 'COC', 'SAAC', 'Comodoro Pierrestegui Airport', NULL, 'AR', 'Entre Rios', -31.2969000, -57.9966000, 'active', '2026-01-31 19:04:18', '2026-01-31 19:04:18'),
(140, 'GHU', 'SAAG', 'Gualeguaychu Airport', NULL, 'AR', 'Entre Rios', -33.0103000, -58.6131000, 'active', '2026-01-31 19:04:18', '2026-01-31 19:04:18'),
(141, 'PRA', 'SAAP', 'General Justo Jose de Urquiza Airport', NULL, 'AR', 'Entre Rios', -31.7948000, -60.4804000, 'active', '2026-01-31 19:04:19', '2026-01-31 19:04:19'),
(142, 'CLX', 'SATC', 'Clorinda Airport', NULL, 'AR', 'Formosa', -25.3036000, -57.7344000, 'active', '2026-01-31 19:04:19', '2026-01-31 19:04:19'),
(143, 'FMA', 'SARF', 'Formosa International Airport (El Pucu Airport)', NULL, 'AR', 'Formosa', -26.2127000, -58.2281000, 'active', '2026-01-31 19:04:20', '2026-01-31 19:04:20'),
(144, 'LLS', 'SATK', 'Alferez Armando Rodriguez Airport', NULL, 'AR', 'Formosa', -24.7214000, -60.5488000, 'active', '2026-01-31 19:04:20', '2026-01-31 19:04:20'),
(145, 'JUJ', 'SASJ', 'Gobernador Horacio Guzman International Airport', NULL, 'AR', 'Jujuy', -24.3928000, -65.0978000, 'active', '2026-01-31 19:04:21', '2026-01-31 19:04:21'),
(146, 'GPO', 'SAZG', 'General Pico Airport', NULL, 'AR', 'La Pampa', -35.6962000, -63.7583000, 'active', '2026-01-31 19:04:21', '2026-01-31 19:04:21'),
(147, 'RSA', 'SAZR', 'Santa Rosa Airport (Argentina)', NULL, 'AR', 'La Pampa', -36.5883000, -64.2757000, 'active', '2026-01-31 19:04:22', '2026-01-31 19:04:22'),
(148, 'IRJ', 'SANL', 'Capitan Vicente Almandos Almonacid Airport', NULL, 'AR', 'La Rioja', -29.3816000, -66.7958000, 'active', '2026-01-31 19:04:22', '2026-01-31 19:04:22'),
(149, 'AFA', 'SAMR', 'San Rafael Airport (Argentina)', NULL, 'AR', 'Mendoza', -34.5883000, -68.4039000, 'active', '2026-01-31 19:04:22', '2026-01-31 19:04:22'),
(150, 'LGS', 'SAMM', 'Comodoro D. Ricardo Salomon Airport', NULL, 'AR', 'Mendoza', -35.4936000, -69.5743000, 'active', '2026-01-31 19:04:23', '2026-01-31 19:04:23'),
(151, 'MDZ', 'SAME', 'Gov. Francisco Gabrielli International Airport (El Plumerillo)', NULL, 'AR', 'Mendoza', -32.8317000, -68.7929000, 'active', '2026-01-31 19:04:23', '2026-01-31 19:04:23'),
(152, 'ELO', 'SATD', 'Eldorado Airport', NULL, 'AR', 'Misiones', -26.3975000, -54.5747000, 'active', '2026-01-31 19:04:24', '2026-01-31 19:04:24'),
(153, 'IGR', 'SARI', 'Cataratas del Iguazu International Airport', NULL, 'AR', 'Misiones', -25.7373000, -54.4734000, 'active', '2026-01-31 19:04:24', '2026-01-31 19:04:24'),
(154, 'PSS', 'SARP', 'Libertador General Jose de San Martin Airport', NULL, 'AR', 'Misiones', -27.3858000, -55.9707000, 'active', '2026-01-31 19:04:25', '2026-01-31 19:04:25'),
(155, 'APZ', 'SAHZ', 'Zapala Airport', NULL, 'AR', 'Neuquen', -38.9755000, -70.1136000, 'active', '2026-01-31 19:04:25', '2026-01-31 19:04:25'),
(156, 'CPC', 'SAZY', 'Aviador Carlos Campos Airport', NULL, 'AR', 'Neuquen', -40.0754000, -71.1373000, 'active', '2026-01-31 19:04:26', '2026-01-31 19:04:26'),
(157, 'CUT', 'SAZW', 'Cutral Co Airport', NULL, 'AR', 'Neuquen', -38.9397000, -69.2646000, 'active', '2026-01-31 19:04:26', '2026-01-31 19:04:26'),
(158, 'CVH', NULL, 'Caviahue Airport', NULL, 'AR', 'Neuquen', -37.8514000, -71.0092000, 'active', '2026-01-31 19:04:26', '2026-01-31 19:04:26'),
(159, 'HOS', 'SAHC', 'Chos Malal Airport', NULL, 'AR', 'Neuquen', -37.4447000, -70.2225000, 'active', '2026-01-31 19:04:27', '2026-01-31 19:04:27'),
(160, 'LCP', NULL, 'Loncopue Airport', NULL, 'AR', 'Neuquen', -38.0819000, -70.6439000, 'active', '2026-01-31 19:04:27', '2026-01-31 19:04:27'),
(161, 'NQN', 'SAZN', 'Presidente Peron International Air', NULL, 'AR', 'Neuquen', -38.9490000, -68.1557000, 'active', '2026-01-31 19:04:28', '2026-01-31 19:04:28'),
(162, 'RDS', 'SAHS', 'Rincon de los Sauces Airport', NULL, 'AR', 'Neuquen', -37.3906000, -68.9042000, 'active', '2026-01-31 19:04:28', '2026-01-31 19:04:28'),
(163, 'BRC', 'SAZS', 'San Carlos de Bariloche Airport', NULL, 'AR', 'Rio Negro', -41.1512000, -71.1575000, 'active', '2026-01-31 19:04:29', '2026-01-31 19:04:29'),
(164, 'CCT', NULL, 'Colonia Catriel Airport', NULL, 'AR', 'Rio Negro', -37.9102000, -67.8350000, 'active', '2026-01-31 19:04:29', '2026-01-31 19:04:29'),
(165, 'EHL', 'SAVB', 'El Bolson Airport', NULL, 'AR', 'Rio Negro', -41.9432000, -71.5323000, 'active', '2026-01-31 19:04:30', '2026-01-31 19:04:30'),
(166, 'GNR', 'SAHR', 'Dr. Arturo Umberto Illia Airport', NULL, 'AR', 'Rio Negro', -39.0007000, -67.6205000, 'active', '2026-01-31 19:04:30', '2026-01-31 19:04:30'),
(167, 'IGB', 'SAVJ', 'Ingeniero Jacobacci Airport (Capitan FAA H. R. Borden Airport)', NULL, 'AR', 'Rio Negro', -41.3209000, -69.5749000, 'active', '2026-01-31 19:04:30', '2026-01-31 19:04:30'),
(168, 'LMD', NULL, 'Los Menucos Airport', NULL, 'AR', 'Rio Negro', -40.8177000, -68.0747000, 'active', '2026-01-31 19:04:31', '2026-01-31 19:04:31'),
(169, 'MQD', 'SAVQ', 'Maquinchao Airport', NULL, 'AR', 'Rio Negro', -41.2431000, -68.7078000, 'active', '2026-01-31 19:04:31', '2026-01-31 19:04:31'),
(170, 'OES', 'SAVN', 'Antoine de Saint Exupery Airport', NULL, 'AR', 'Rio Negro', -40.7512000, -65.0343000, 'active', '2026-01-31 19:04:32', '2026-01-31 19:04:32'),
(171, 'SGV', 'SAVS', 'Sierra Grande Airport', NULL, 'AR', 'Rio Negro', -41.5917000, -65.3394000, 'active', '2026-01-31 19:04:32', '2026-01-31 19:04:32'),
(172, 'VCF', NULL, 'Valcheta Airport', NULL, 'AR', 'Rio Negro', -40.7000000, -66.1500000, 'active', '2026-01-31 19:04:33', '2026-01-31 19:04:33'),
(173, 'VDM', 'SAVV', 'Gobernador Edgardo Castello Airport', NULL, 'AR', 'Rio Negro', -40.8692000, -63.0004000, 'active', '2026-01-31 19:04:33', '2026-01-31 19:04:33'),
(174, 'ORA', 'SASO', 'Oran Air', NULL, 'AR', 'Salta', -23.1528000, -64.3292000, 'active', '2026-01-31 19:04:33', '2026-01-31 19:04:33'),
(175, 'SLA', 'SASA', 'Martin Miguel de Guemes International Airport', NULL, 'AR', 'Salta', -24.8560000, -65.4862000, 'active', '2026-01-31 19:04:34', '2026-01-31 19:04:34'),
(176, 'TTG', 'SAST', 'Tartagal Airport', NULL, 'AR', 'Salta', -22.6196000, -63.7937000, 'active', '2026-01-31 19:04:34', '2026-01-31 19:04:34'),
(177, 'UAQ', 'SANU', 'Domingo Faustino Sarmiento Airport', NULL, 'AR', 'San Juan', -31.5715000, -68.4182000, 'active', '2026-01-31 19:04:35', '2026-01-31 19:04:35'),
(178, 'LUQ', 'SAOU', 'Brigadier Mayor Cesar Raul Ojeda Airport', NULL, 'AR', 'San Luis', -33.2732000, -66.3564000, 'active', '2026-01-31 19:04:35', '2026-01-31 19:04:35'),
(179, 'RLO', 'SAOS', 'Valle del Conlara Airport', NULL, 'AR', 'San Luis', -32.3847000, -65.1865000, 'active', '2026-01-31 19:04:36', '2026-01-31 19:04:36'),
(180, 'VME', 'SAOR', 'Villa Reynolds Airport', NULL, 'AR', 'San Luis', -33.7299000, -65.3874000, 'active', '2026-01-31 19:04:36', '2026-01-31 19:04:36'),
(181, 'CVI', NULL, 'Caleta Olivia Airport', NULL, 'AR', 'Santa Cruz', -46.4318000, -67.5186000, 'active', '2026-01-31 19:04:36', '2026-01-31 19:04:36'),
(182, 'FTE', 'SAWA', 'Comandante Armando Tola International Airport', NULL, 'AR', 'Santa Cruz', -50.2803000, -72.0531000, 'active', '2026-01-31 19:04:37', '2026-01-31 19:04:37'),
(183, 'GGS', 'SAWR', 'Gobernador Gregores Airport', NULL, 'AR', 'Santa Cruz', -48.7831000, -70.1500000, 'active', '2026-01-31 19:04:37', '2026-01-31 19:04:37'),
(184, 'LHS', 'SAVH', 'Las Heras Airport', NULL, 'AR', 'Santa Cruz', -46.5383000, -68.9653000, 'active', '2026-01-31 19:04:37', '2026-01-31 19:04:37'),
(185, 'PMQ', 'SAWP', 'Perito Moreno Airport', NULL, 'AR', 'Santa Cruz', -46.5379000, -70.9787000, 'active', '2026-01-31 19:04:38', '2026-01-31 19:04:38'),
(186, 'PUD', 'SAWD', 'Puerto Deseado Airport', NULL, 'AR', 'Santa Cruz', -47.7353000, -65.9041000, 'active', '2026-01-31 19:04:38', '2026-01-31 19:04:38'),
(187, 'RGL', 'SAWG', 'Piloto Civil Norberto Fernandez International Airport', NULL, 'AR', 'Santa Cruz', -51.6089000, -69.3126000, 'active', '2026-01-31 19:04:38', '2026-01-31 19:04:38'),
(188, 'RYO', 'SAWT', 'Rio Turbio Airport', NULL, 'AR', 'Santa Cruz', -51.6050000, -72.2203000, 'active', '2026-01-31 19:04:39', '2026-01-31 19:04:39'),
(189, 'RZA', 'SAWU', 'Santa Cruz Airport (Argentina)', NULL, 'AR', 'Santa Cruz', -50.0165000, -68.5792000, 'active', '2026-01-31 19:04:39', '2026-01-31 19:04:39'),
(190, 'ULA', 'SAWJ', 'Capitan Jose Daniel Vazquez Airport', NULL, 'AR', 'Santa Cruz', -49.3068000, -67.8026000, 'active', '2026-01-31 19:04:40', '2026-01-31 19:04:40'),
(191, 'CRR', 'SANW', 'Ceres Airport', NULL, 'AR', 'Santa Fe', -29.8723000, -61.9279000, 'active', '2026-01-31 19:04:40', '2026-01-31 19:04:40'),
(192, 'NCJ', 'SAFS', 'Sunchales Airport', NULL, 'AR', 'Santa Fe', -30.9575000, -61.5283000, 'active', '2026-01-31 19:04:41', '2026-01-31 19:04:41'),
(193, 'RAF', 'SAFR', 'Rafaela Airport', NULL, 'AR', 'Santa Fe', -31.2825000, -61.5017000, 'active', '2026-01-31 19:04:41', '2026-01-31 19:04:41'),
(194, 'RCQ', 'SATR', 'Reconquista Airport', NULL, 'AR', 'Santa Fe', -29.2103000, -59.6800000, 'active', '2026-01-31 19:04:42', '2026-01-31 19:04:42'),
(195, 'ROS', 'SAAR', 'Rosario - Islas Malvinas International Airport', NULL, 'AR', 'Santa Fe', -32.9036000, -60.7850000, 'active', '2026-01-31 19:04:42', '2026-01-31 19:04:42'),
(196, 'SFN', 'SAAV', 'Sauce Viejo Airport', NULL, 'AR', 'Santa Fe', -31.7117000, -60.8117000, 'active', '2026-01-31 19:04:42', '2026-01-31 19:04:42'),
(197, 'RHD', 'SANR', 'Termas de Rio Hondo Airport', NULL, 'AR', 'Santiago del Estero', -27.4966000, -64.9360000, 'active', '2026-01-31 19:04:43', '2026-01-31 19:04:43'),
(198, 'SDE', 'SANE', 'Vicecomodoro Angel de la Paz Aragones Airport', NULL, 'AR', 'Santiago del Estero', -27.7656000, -64.3100000, 'active', '2026-01-31 19:04:43', '2026-01-31 19:04:43'),
(199, 'RGA', 'SAWE', 'Hermes Quijada International Airport', NULL, 'AR', 'Tierra del Fuego', -53.7777000, -67.7494000, 'active', '2026-01-31 19:04:44', '2026-01-31 19:04:44'),
(200, 'USH', 'SAWH', 'Ushuaia - Malvinas Argentinas International Airport', NULL, 'AR', 'Tierra del Fuego', -54.8433000, -68.2958000, 'active', '2026-01-31 19:04:44', '2026-01-31 19:04:44'),
(201, 'TUC', 'SANT', 'Teniente General Benjamin Matienzo International Airport', NULL, 'AR', 'Tucuman', -26.8409000, -65.1049000, 'active', '2026-01-31 19:04:45', '2026-01-31 19:04:45'),
(202, 'OFU', 'NSAS', 'Ofu Airport', NULL, 'AS', 'Eastern District', -14.1844000, -169.6700000, 'active', '2026-01-31 19:04:45', '2026-01-31 19:04:45'),
(203, 'PPG', 'NSTU', 'Pago Pago International Airport', NULL, 'AS', 'Eastern District', -14.3310000, -170.7100000, 'active', '2026-01-31 19:04:46', '2026-01-31 19:04:46'),
(204, 'TAV', NULL, 'Tau Airport', NULL, 'AS', 'Eastern District', -14.2292000, -169.5110000, 'active', '2026-01-31 19:04:46', '2026-01-31 19:04:46'),
(205, 'KLU', 'LOWK', 'Klagenfurt Airport', NULL, 'AT', 'Karnten', 46.6425000, 14.3377000, 'active', '2026-01-31 19:04:46', '2026-01-31 19:04:46'),
(206, 'VIE', 'LOWW', 'Vienna International Airport', NULL, 'AT', 'Niederosterreich', 48.1103000, 16.5697000, 'active', '2026-01-31 19:04:47', '2026-01-31 19:04:47'),
(207, 'LNZ', 'LOWL', 'Linz Airport (Blue Danube Airport)', NULL, 'AT', 'Oberosterreich', 48.2332000, 14.1875000, 'active', '2026-01-31 19:04:47', '2026-01-31 19:04:47'),
(208, 'SZG', 'LOWS', 'Salzburg Airport', NULL, 'AT', 'Salzburg', 47.7933000, 13.0043000, 'active', '2026-01-31 19:04:48', '2026-01-31 19:04:48'),
(209, 'GRZ', 'LOWG', 'Graz Airport', NULL, 'AT', 'Steiermark', 46.9911000, 15.4396000, 'active', '2026-01-31 19:04:48', '2026-01-31 19:04:48'),
(210, 'INN', 'LOWI', 'Innsbruck Airport (Kranebitten Airport)', NULL, 'AT', 'Tirol', 47.2602000, 11.3440000, 'active', '2026-01-31 19:04:49', '2026-01-31 19:04:49'),
(211, 'HOH', 'LOIH', 'Hohenems-Dornbirn Airport', NULL, 'AT', 'Vorarlberg', 47.3850000, 9.7000000, 'active', '2026-01-31 19:04:49', '2026-01-31 19:04:49'),
(212, 'CBR', 'YSCB', 'Canberra Airport', NULL, 'AU', 'Australian Capital Territory', -35.3069000, 149.1950000, 'active', '2026-01-31 19:04:49', '2026-01-31 19:04:49'),
(213, 'ABX', 'YMAY', 'Albury Airport', NULL, 'AU', 'New South Wales', -36.0678000, 146.9580000, 'active', '2026-01-31 19:04:50', '2026-01-31 19:04:50'),
(214, 'ARM', 'YARM', 'Armidale Airport', NULL, 'AU', 'New South Wales', -30.5281000, 151.6170000, 'active', '2026-01-31 19:04:50', '2026-01-31 19:04:50'),
(215, 'BEO', 'YLMQ', 'Lake Macquarie Airport (Belmont Airport)', NULL, 'AU', 'New South Wales', -33.0667000, 151.6480000, 'active', '2026-01-31 19:04:50', '2026-01-31 19:04:50'),
(216, 'BHQ', 'YBHI', 'Broken Hill Airport', NULL, 'AU', 'New South Wales', -32.0014000, 141.4720000, 'active', '2026-01-31 19:04:51', '2026-01-31 19:04:51'),
(217, 'BHS', 'YBTH', 'Bathurst Airport', NULL, 'AU', 'New South Wales', -33.4094000, 149.6520000, 'active', '2026-01-31 19:04:51', '2026-01-31 19:04:51'),
(218, 'BNK', 'YBNA', 'Ballina Byron Gateway Airport', NULL, 'AU', 'New South Wales', -28.8339000, 153.5620000, 'active', '2026-01-31 19:04:52', '2026-01-31 19:04:52'),
(219, 'BRK', 'YBKE', 'Bourke Airport', NULL, 'AU', 'New South Wales', -30.0392000, 145.9520000, 'active', '2026-01-31 19:04:52', '2026-01-31 19:04:52'),
(220, 'BWQ', 'YBRW', 'Brewarrina Airport', NULL, 'AU', 'New South Wales', -29.9739000, 146.8170000, 'active', '2026-01-31 19:04:53', '2026-01-31 19:04:53'),
(221, 'BWU', 'YSBK', 'Bankstown Airport', NULL, 'AU', 'New South Wales', -33.9244000, 150.9880000, 'active', '2026-01-31 19:04:53', '2026-01-31 19:04:53'),
(222, 'BZD', 'YBRN', 'Balranald Airport', NULL, 'AU', 'New South Wales', -34.6236000, 143.5780000, 'active', '2026-01-31 19:04:53', '2026-01-31 19:04:53'),
(223, 'CAZ', 'YCBA', 'Cobar Airport', NULL, 'AU', 'New South Wales', -31.5383000, 145.7940000, 'active', '2026-01-31 19:04:54', '2026-01-31 19:04:54'),
(224, 'CBX', 'YCDO', 'Condobolin Airport', NULL, 'AU', 'New South Wales', -33.0644000, 147.2090000, 'active', '2026-01-31 19:04:54', '2026-01-31 19:04:54'),
(225, 'CDU', 'YSCN', 'Camden Airport', NULL, 'AU', 'New South Wales', -34.0403000, 150.6870000, 'active', '2026-01-31 19:04:55', '2026-01-31 19:04:55'),
(226, 'CES', 'YCNK', 'Cessnock Airport', NULL, 'AU', 'New South Wales', -32.7875000, 151.3420000, 'active', '2026-01-31 19:04:55', '2026-01-31 19:04:55'),
(227, 'CFS', 'YCFS', 'Coffs Harbour Airport', NULL, 'AU', 'New South Wales', -30.3206000, 153.1160000, 'active', '2026-01-31 19:04:56', '2026-01-31 19:04:56'),
(228, 'CLH', 'YCAH', 'Coolah Airport', NULL, 'AU', 'New South Wales', -31.7733000, 149.6100000, 'active', '2026-01-31 19:04:56', '2026-01-31 19:04:56'),
(229, 'CMD', 'YCTM', 'Cootamundra Airport', NULL, 'AU', 'New South Wales', -34.6239000, 148.0280000, 'active', '2026-01-31 19:04:57', '2026-01-31 19:04:57'),
(230, 'CNB', 'YCNM', 'Coonamble Airport', NULL, 'AU', 'New South Wales', -30.9833000, 148.3760000, 'active', '2026-01-31 19:04:57', '2026-01-31 19:04:57'),
(231, 'COJ', 'YCBB', 'Coonabarabran Airport', NULL, 'AU', 'New South Wales', -31.3325000, 149.2670000, 'active', '2026-01-31 19:04:57', '2026-01-31 19:04:57'),
(232, 'CRB', 'YCBR', 'Collarenebri Airport', NULL, 'AU', 'New South Wales', -29.5217000, 148.5820000, 'active', '2026-01-31 19:04:58', '2026-01-31 19:04:58'),
(233, 'CSI', 'YCAS', 'Casino Airport', NULL, 'AU', 'New South Wales', -28.8828000, 153.0670000, 'active', '2026-01-31 19:04:58', '2026-01-31 19:04:58'),
(234, 'CUG', 'YCUA', 'Cudal Airport', NULL, 'AU', 'New South Wales', -33.2783000, 148.7630000, 'active', '2026-01-31 19:04:59', '2026-01-31 19:04:59'),
(235, 'CWT', 'YCWR', 'Cowra Airport', NULL, 'AU', 'New South Wales', -33.8447000, 148.6490000, 'active', '2026-01-31 19:04:59', '2026-01-31 19:04:59'),
(236, 'CWW', 'YCOR', 'Corowa Airport', NULL, 'AU', 'New South Wales', -35.9947000, 146.3570000, 'active', '2026-01-31 19:05:00', '2026-01-31 19:05:00'),
(237, 'DBO', 'YSDU', 'Dubbo City Regional Airport', NULL, 'AU', 'New South Wales', -32.2167000, 148.5750000, 'active', '2026-01-31 19:05:00', '2026-01-31 19:05:00'),
(238, 'DGE', 'YMDG', 'Mudgee Airport', NULL, 'AU', 'New South Wales', -32.5625000, 149.6110000, 'active', '2026-01-31 19:05:00', '2026-01-31 19:05:00'),
(239, 'DNQ', 'YDLQ', 'Deniliquin Airport', NULL, 'AU', 'New South Wales', -35.5594000, 144.9460000, 'active', '2026-01-31 19:05:01', '2026-01-31 19:05:01'),
(240, 'EVH', 'YEVD', 'Evans Head Memorial Aerodrome', NULL, 'AU', 'New South Wales', -29.0933000, 153.4200000, 'active', '2026-01-31 19:05:01', '2026-01-31 19:05:01'),
(241, 'FLY', 'YFIL', 'Finley Airport', NULL, 'AU', 'New South Wales', -35.6667000, 145.5500000, 'active', '2026-01-31 19:05:01', '2026-01-31 19:05:01'),
(242, 'FOT', 'YFST', 'Forster (Wallis Island) Airport', NULL, 'AU', 'New South Wales', -32.2042000, 152.4790000, 'active', '2026-01-31 19:05:02', '2026-01-31 19:05:02'),
(243, 'FRB', 'YFBS', 'Forbes Airport', NULL, 'AU', 'New South Wales', -33.3636000, 147.9350000, 'active', '2026-01-31 19:05:02', '2026-01-31 19:05:02'),
(244, 'GFE', NULL, 'Grenfell Airport', NULL, 'AU', 'New South Wales', -34.0000000, 148.1330000, 'active', '2026-01-31 19:05:03', '2026-01-31 19:05:03'),
(245, 'GFF', 'YGTH', 'Griffith Airport', NULL, 'AU', 'New South Wales', -34.2508000, 146.0670000, 'active', '2026-01-31 19:05:03', '2026-01-31 19:05:03'),
(246, 'GFN', 'YGFN', 'Clarence Valley Regional Airport', NULL, 'AU', 'New South Wales', -29.7594000, 153.0300000, 'active', '2026-01-31 19:05:04', '2026-01-31 19:05:04'),
(247, 'GLI', 'YGLI', 'Glen Innes Airport', NULL, 'AU', 'New South Wales', -29.6750000, 151.6890000, 'active', '2026-01-31 19:05:04', '2026-01-31 19:05:04'),
(248, 'GOS', 'YSMB', 'Somersby Airfield', NULL, 'AU', 'New South Wales', -33.3678000, 151.3000000, 'active', '2026-01-31 19:05:05', '2026-01-31 19:05:05'),
(249, 'GUH', 'YGDH', 'Gunnedah Airport', NULL, 'AU', 'New South Wales', -30.9611000, 150.2510000, 'active', '2026-01-31 19:05:05', '2026-01-31 19:05:05'),
(250, 'GUL', 'YGLB', 'Goulburn Airport', NULL, 'AU', 'New South Wales', -34.8103000, 149.7260000, 'active', '2026-01-31 19:05:05', '2026-01-31 19:05:05'),
(251, 'HXX', 'YHAY', 'Hay Airport', NULL, 'AU', 'New South Wales', -34.5314000, 144.8300000, 'active', '2026-01-31 19:05:06', '2026-01-31 19:05:06'),
(252, 'IVR', 'YIVL', 'Inverell Airport', NULL, 'AU', 'New South Wales', -29.8883000, 151.1440000, 'active', '2026-01-31 19:05:06', '2026-01-31 19:05:06'),
(253, 'KPS', 'YKMP', 'Kempsey Airport', NULL, 'AU', 'New South Wales', -31.0744000, 152.7700000, 'active', '2026-01-31 19:05:06', '2026-01-31 19:05:06'),
(254, 'LBH', NULL, 'Palm Beach Water Airport', NULL, 'AU', 'New South Wales', -33.5871000, 151.3230000, 'active', '2026-01-31 19:05:07', '2026-01-31 19:05:07'),
(255, 'LDH', 'YLHI', 'Lord Howe Island Airport', NULL, 'AU', 'New South Wales', -31.5383000, 159.0770000, 'active', '2026-01-31 19:05:07', '2026-01-31 19:05:07'),
(256, 'LHG', 'YLRD', 'Lightning Ridge Airport', NULL, 'AU', 'New South Wales', -29.4567000, 147.9840000, 'active', '2026-01-31 19:05:08', '2026-01-31 19:05:08'),
(257, 'LSY', 'YLIS', 'Lismore Airport', NULL, 'AU', 'New South Wales', -28.8303000, 153.2600000, 'active', '2026-01-31 19:05:08', '2026-01-31 19:05:08'),
(258, 'MIM', 'YMER', 'Merimbula Airport', NULL, 'AU', 'New South Wales', -36.9086000, 149.9010000, 'active', '2026-01-31 19:05:08', '2026-01-31 19:05:08'),
(259, 'MRZ', 'YMOR', 'Moree Airport', NULL, 'AU', 'New South Wales', -29.4989000, 149.8450000, 'active', '2026-01-31 19:05:09', '2026-01-31 19:05:09'),
(260, 'MTL', 'YMND', 'Maitland Airport', NULL, 'AU', 'New South Wales', -32.7013000, 151.4930000, 'active', '2026-01-31 19:05:09', '2026-01-31 19:05:09'),
(261, 'MVH', NULL, 'Macksville Airport', NULL, 'AU', 'New South Wales', -30.7000000, 152.9170000, 'active', '2026-01-31 19:05:10', '2026-01-31 19:05:10'),
(262, 'MYA', 'YMRY', 'Moruya Airport', NULL, 'AU', 'New South Wales', -35.8978000, 150.1440000, 'active', '2026-01-31 19:05:10', '2026-01-31 19:05:10'),
(263, 'NAA', 'YNBR', 'Narrabri Airport', NULL, 'AU', 'New South Wales', -30.3192000, 149.8270000, 'active', '2026-01-31 19:05:10', '2026-01-31 19:05:10'),
(264, 'NBH', 'YNHS', 'Nambucca Heads Airport', NULL, 'AU', 'New South Wales', -30.6500000, 153.0000000, 'active', '2026-01-31 19:05:11', '2026-01-31 19:05:11'),
(265, 'NGA', 'YYNG', 'Young Airport', NULL, 'AU', 'New South Wales', -34.2556000, 148.2480000, 'active', '2026-01-31 19:05:11', '2026-01-31 19:05:11'),
(266, 'NOA', 'YSNW', 'NAS Nowra', NULL, 'AU', 'New South Wales', -34.9489000, 150.5370000, 'active', '2026-01-31 19:05:11', '2026-01-31 19:05:11'),
(267, 'NRA', 'YNAR', 'Narrandera Airport', NULL, 'AU', 'New South Wales', -34.7022000, 146.5120000, 'active', '2026-01-31 19:05:12', '2026-01-31 19:05:12'),
(268, 'NSO', 'YSCO', 'Scone Airport', NULL, 'AU', 'New South Wales', -32.0372000, 150.8320000, 'active', '2026-01-31 19:05:12', '2026-01-31 19:05:12'),
(269, 'NTL', 'YWLM', 'Newcastle Airport / RAAF Base Williamtown', NULL, 'AU', 'New South Wales', -32.7950000, 151.8340000, 'active', '2026-01-31 19:05:13', '2026-01-31 19:05:13'),
(270, 'NYN', 'YNYN', 'Nyngan Airport', NULL, 'AU', 'New South Wales', -31.5511000, 147.2030000, 'active', '2026-01-31 19:05:13', '2026-01-31 19:05:13'),
(271, 'OAG', 'YORG', 'Orange Airport', NULL, 'AU', 'New South Wales', -33.3817000, 149.1330000, 'active', '2026-01-31 19:05:13', '2026-01-31 19:05:13'),
(272, 'OOM', 'YCOM', 'Cooma-Snowy Mountains Airport', NULL, 'AU', 'New South Wales', -36.3006000, 148.9740000, 'active', '2026-01-31 19:05:14', '2026-01-31 19:05:14'),
(273, 'PKE', 'YPKS', 'Parkes Airport', NULL, 'AU', 'New South Wales', -33.1314000, 148.2390000, 'active', '2026-01-31 19:05:14', '2026-01-31 19:05:14'),
(274, 'PQQ', 'YPMQ', 'Port Macquarie Airport', NULL, 'AU', 'New South Wales', -31.4358000, 152.8630000, 'active', '2026-01-31 19:05:14', '2026-01-31 19:05:14'),
(275, 'RSE', NULL, 'Rose Bay Water Airport', NULL, 'AU', 'New South Wales', -33.8690000, 151.2620000, 'active', '2026-01-31 19:05:15', '2026-01-31 19:05:15'),
(276, 'SIX', 'YSGT', 'Singleton Airport', NULL, 'AU', 'New South Wales', -32.6008000, 151.1930000, 'active', '2026-01-31 19:05:15', '2026-01-31 19:05:15'),
(277, 'SYD', 'YSSY', 'Sydney Airport (Kingsford Smith Airport)', NULL, 'AU', 'New South Wales', -33.9461000, 151.1770000, 'active', '2026-01-31 19:05:16', '2026-01-31 19:05:16'),
(278, 'TCW', 'YTOC', 'Tocumwal Airport', NULL, 'AU', 'New South Wales', -35.8117000, 145.6080000, 'active', '2026-01-31 19:05:16', '2026-01-31 19:05:16'),
(279, 'TEM', 'YTEM', 'Temora Airport', NULL, 'AU', 'New South Wales', -34.4214000, 147.5120000, 'active', '2026-01-31 19:05:16', '2026-01-31 19:05:16'),
(280, 'TMW', 'YSTW', 'Tamworth Regional Airport', NULL, 'AU', 'New South Wales', -31.0839000, 150.8470000, 'active', '2026-01-31 19:05:17', '2026-01-31 19:05:17'),
(281, 'TRO', 'YTRE', 'Taree Airport', NULL, 'AU', 'New South Wales', -31.8886000, 152.5140000, 'active', '2026-01-31 19:05:17', '2026-01-31 19:05:17'),
(282, 'TUM', 'YTMU', 'Tumut Airport', NULL, 'AU', 'New South Wales', -35.2628000, 148.2410000, 'active', '2026-01-31 19:05:18', '2026-01-31 19:05:18'),
(283, 'TYB', 'YTIB', 'Tibooburra Airport', NULL, 'AU', 'New South Wales', -29.4511000, 142.0580000, 'active', '2026-01-31 19:05:18', '2026-01-31 19:05:18'),
(284, 'UIR', 'YQDI', 'Quirindi Airport', NULL, 'AU', 'New South Wales', -31.4906000, 150.5140000, 'active', '2026-01-31 19:05:18', '2026-01-31 19:05:18'),
(285, 'WAU', NULL, 'Wauchope Airport', NULL, 'AU', 'New South Wales', -20.6406000, 134.2150000, 'active', '2026-01-31 19:05:19', '2026-01-31 19:05:19'),
(286, 'WEW', 'YWWA', 'Wee Waa Airport', NULL, 'AU', 'New South Wales', -30.2583000, 149.4080000, 'active', '2026-01-31 19:05:19', '2026-01-31 19:05:19'),
(287, 'WGA', 'YSWG', 'Wagga Wagga Airport', NULL, 'AU', 'New South Wales', -35.1653000, 147.4660000, 'active', '2026-01-31 19:05:20', '2026-01-31 19:05:20'),
(288, 'WGE', 'YWLG', 'Walgett Airport', NULL, 'AU', 'New South Wales', -30.0328000, 148.1260000, 'active', '2026-01-31 19:05:20', '2026-01-31 19:05:20'),
(289, 'WIO', 'YWCA', 'Wilcannia Airport', NULL, 'AU', 'New South Wales', -31.5264000, 143.3750000, 'active', '2026-01-31 19:05:21', '2026-01-31 19:05:21'),
(290, 'WLC', 'YWCH', 'Walcha Airport', NULL, 'AU', 'New South Wales', -31.0000000, 151.5670000, 'active', '2026-01-31 19:05:21', '2026-01-31 19:05:21'),
(291, 'WOL', 'YWOL', 'Illawarra Regional Airport', NULL, 'AU', 'New South Wales', -34.5611000, 150.7890000, 'active', '2026-01-31 19:05:21', '2026-01-31 19:05:21'),
(292, 'WWY', 'YWWL', 'West Wyalong Airport', NULL, 'AU', 'New South Wales', -33.9372000, 147.1910000, 'active', '2026-01-31 19:05:22', '2026-01-31 19:05:22'),
(293, 'XRH', 'YSRI', 'RAAF Base Richmond', NULL, 'AU', 'New South Wales', -33.6006000, 150.7810000, 'active', '2026-01-31 19:05:22', '2026-01-31 19:05:22'),
(294, 'AMX', NULL, 'Ammaroo Airport', NULL, 'AU', 'Northern Territory', -21.7383000, 135.2420000, 'active', '2026-01-31 19:05:22', '2026-01-31 19:05:22'),
(295, 'ANZ', NULL, 'Angus Downs Airport', NULL, 'AU', 'Northern Territory', -25.0325000, 132.2750000, 'active', '2026-01-31 19:05:23', '2026-01-31 19:05:23'),
(296, 'ASP', 'YBAS', 'Alice Springs Airport', NULL, 'AU', 'Northern Territory', -23.8067000, 133.9020000, 'active', '2026-01-31 19:05:23', '2026-01-31 19:05:23'),
(297, 'AVG', 'YAUV', 'Auvergne Airport', NULL, 'AU', 'Northern Territory', -15.7000000, 130.0000000, 'active', '2026-01-31 19:05:24', '2026-01-31 19:05:24'),
(298, 'AWP', NULL, 'Austral Downs Airport', NULL, 'AU', 'Northern Territory', -20.5000000, 137.7500000, 'active', '2026-01-31 19:05:24', '2026-01-31 19:05:24'),
(299, 'AXL', 'YALX', 'Alexandria Homestead Airport', NULL, 'AU', 'Northern Territory', -19.0602000, 136.7100000, 'active', '2026-01-31 19:05:24', '2026-01-31 19:05:24'),
(300, 'AYD', NULL, 'Alroy Downs Airport', NULL, 'AU', 'Northern Territory', -19.2908000, 136.0790000, 'active', '2026-01-31 19:05:25', '2026-01-31 19:05:25'),
(301, 'AYL', NULL, 'Anthony Lagoon Airport', NULL, 'AU', 'Northern Territory', -18.0181000, 135.5350000, 'active', '2026-01-31 19:05:25', '2026-01-31 19:05:25'),
(302, 'AYQ', 'YAYE', 'Ayers Rock Airport', NULL, 'AU', 'Northern Territory', -25.1861000, 130.9760000, 'active', '2026-01-31 19:05:25', '2026-01-31 19:05:25'),
(303, 'BCZ', NULL, 'Bickerton Island Airport', NULL, 'AU', 'Northern Territory', -13.7808000, 136.2020000, 'active', '2026-01-31 19:05:26', '2026-01-31 19:05:26'),
(304, 'BOX', 'YBRL', 'Borroloola Airport', NULL, 'AU', 'Northern Territory', -16.0753000, 136.3020000, 'active', '2026-01-31 19:05:26', '2026-01-31 19:05:26'),
(305, 'BRT', 'YBTI', 'Bathurst Island Airport', NULL, 'AU', 'Northern Territory', -11.7692000, 130.6200000, 'active', '2026-01-31 19:05:26', '2026-01-31 19:05:26'),
(306, 'BTD', NULL, 'Brunette Downs Airport', NULL, 'AU', 'Northern Territory', -18.6400000, 135.9380000, 'active', '2026-01-31 19:05:27', '2026-01-31 19:05:27'),
(307, 'BYX', NULL, 'Baniyala Airport', NULL, 'AU', 'Northern Territory', -13.1981000, 136.2270000, 'active', '2026-01-31 19:05:27', '2026-01-31 19:05:27'),
(308, 'CDA', 'YCOO', 'Cooinda Airport', NULL, 'AU', 'Northern Territory', -12.9033000, 132.5320000, 'active', '2026-01-31 19:05:28', '2026-01-31 19:05:28'),
(309, 'CFI', 'YCFD', 'Camfield Airport', NULL, 'AU', 'Northern Territory', -17.0217000, 131.3270000, 'active', '2026-01-31 19:05:28', '2026-01-31 19:05:28'),
(310, 'CKI', 'YCKI', 'Croker Island Airport', NULL, 'AU', 'Northern Territory', -11.1650000, 132.4830000, 'active', '2026-01-31 19:05:28', '2026-01-31 19:05:28'),
(311, 'COB', NULL, 'Coolibah Airport', NULL, 'AU', 'Northern Territory', -15.5483000, 130.9620000, 'active', '2026-01-31 19:05:29', '2026-01-31 19:05:29'),
(312, 'CSD', NULL, 'Cresswell Downs Airport', NULL, 'AU', 'Northern Territory', -17.9480000, 135.9160000, 'active', '2026-01-31 19:05:29', '2026-01-31 19:05:29'),
(313, 'CTR', NULL, 'Cattle Creek Airport', NULL, 'AU', 'Northern Territory', -17.6070000, 131.5490000, 'active', '2026-01-31 19:05:29', '2026-01-31 19:05:29'),
(314, 'DKV', 'YDVR', 'Docker River Airport', NULL, 'AU', 'Northern Territory', -24.8600000, 129.0700000, 'active', '2026-01-31 19:05:30', '2026-01-31 19:05:30'),
(315, 'DLV', 'YDLV', 'Delissaville Airport', NULL, 'AU', 'Northern Territory', -12.5500000, 130.6850000, 'active', '2026-01-31 19:05:30', '2026-01-31 19:05:30'),
(316, 'DRW', 'YPDN', 'Darwin International Airport', NULL, 'AU', 'Northern Territory', -12.4147000, 130.8770000, 'active', '2026-01-31 19:05:31', '2026-01-31 19:05:31'),
(317, 'DVR', NULL, 'Daly River Airport', NULL, 'AU', 'Northern Territory', -13.7498000, 130.6940000, 'active', '2026-01-31 19:05:31', '2026-01-31 19:05:31'),
(318, 'DYW', NULL, 'Daly Waters Airport', NULL, 'AU', 'Northern Territory', -16.2647000, 133.3830000, 'active', '2026-01-31 19:05:31', '2026-01-31 19:05:31'),
(319, 'EDD', NULL, 'Erldunda Airport', NULL, 'AU', 'Northern Territory', -25.2058000, 133.2540000, 'active', '2026-01-31 19:05:32', '2026-01-31 19:05:32'),
(320, 'EKD', NULL, 'Elkedra Airport', NULL, 'AU', 'Northern Territory', -21.1725000, 135.4440000, 'active', '2026-01-31 19:05:32', '2026-01-31 19:05:32'),
(321, 'ELC', 'YELD', 'Elcho Island Airport', NULL, 'AU', 'Northern Territory', -12.0194000, 135.5710000, 'active', '2026-01-31 19:05:32', '2026-01-31 19:05:32'),
(322, 'EVD', NULL, 'Eva Downs Airport', NULL, 'AU', 'Northern Territory', -18.0010000, 134.8630000, 'active', '2026-01-31 19:05:33', '2026-01-31 19:05:33'),
(323, 'FIK', 'YFNE', 'Finke Airport', NULL, 'AU', 'Northern Territory', -25.5947000, 134.5830000, 'active', '2026-01-31 19:05:33', '2026-01-31 19:05:33');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(324, 'GBL', 'YGBI', 'South Goulburn Island Airport', NULL, 'AU', 'Northern Territory', -11.6500000, 133.3820000, 'active', '2026-01-31 19:05:33', '2026-01-31 19:05:33'),
(325, 'GOV', 'YPGV', 'Gove Airport', NULL, 'AU', 'Northern Territory', -12.2694000, 136.8180000, 'active', '2026-01-31 19:05:34', '2026-01-31 19:05:34'),
(326, 'GPN', 'YGPT', 'Garden Point Airport', NULL, 'AU', 'Northern Territory', -11.4025000, 130.4220000, 'active', '2026-01-31 19:05:34', '2026-01-31 19:05:34'),
(327, 'GTE', 'YGTE', 'Groote Eylandt Airport', NULL, 'AU', 'Northern Territory', -13.9750000, 136.4600000, 'active', '2026-01-31 19:05:34', '2026-01-31 19:05:34'),
(328, 'GTS', 'YTGT', 'The Granites Airport', NULL, 'AU', 'Northern Territory', -26.9483000, 133.6070000, 'active', '2026-01-31 19:05:35', '2026-01-31 19:05:35'),
(329, 'HMG', 'YHMB', 'Hermannsburg Airport', NULL, 'AU', 'Northern Territory', -23.9300000, 132.8050000, 'active', '2026-01-31 19:05:35', '2026-01-31 19:05:35'),
(330, 'HOK', 'YHOO', 'Hooker Creek Airport', NULL, 'AU', 'Northern Territory', -18.3367000, 130.6380000, 'active', '2026-01-31 19:05:36', '2026-01-31 19:05:36'),
(331, 'HRY', 'YHBY', 'Henbury Airport', NULL, 'AU', 'Northern Territory', -24.5840000, 133.2360000, 'active', '2026-01-31 19:05:36', '2026-01-31 19:05:36'),
(332, 'HUB', 'YHBR', 'Humbert River Airport', NULL, 'AU', 'Northern Territory', -16.4897000, 130.6300000, 'active', '2026-01-31 19:05:36', '2026-01-31 19:05:36'),
(333, 'IVW', 'YINW', 'Inverway Airport', NULL, 'AU', 'Northern Territory', -17.8411000, 129.6430000, 'active', '2026-01-31 19:05:37', '2026-01-31 19:05:37'),
(334, 'JAB', 'YJAB', 'Jabiru Airport', NULL, 'AU', 'Northern Territory', -12.6583000, 132.8930000, 'active', '2026-01-31 19:05:37', '2026-01-31 19:05:37'),
(335, 'KBB', NULL, 'Kirkimbie Airport', NULL, 'AU', 'Northern Territory', -17.7792000, 129.2100000, 'active', '2026-01-31 19:05:37', '2026-01-31 19:05:37'),
(336, 'KBJ', 'YKCA', 'Kings Canyon Airport', NULL, 'AU', 'Northern Territory', -24.2600000, 131.4900000, 'active', '2026-01-31 19:05:38', '2026-01-31 19:05:38'),
(337, 'KCS', 'YKCS', 'Kings Creek Station Airport', NULL, 'AU', 'Northern Territory', -24.4233000, 131.8350000, 'active', '2026-01-31 19:05:38', '2026-01-31 19:05:38'),
(338, 'KFG', 'YKKG', 'Kalkgurung Airport', NULL, 'AU', 'Northern Territory', -17.4319000, 130.8080000, 'active', '2026-01-31 19:05:38', '2026-01-31 19:05:38'),
(339, 'KGR', NULL, 'Kulgera Airport', NULL, 'AU', 'Northern Territory', -25.8428000, 133.2920000, 'active', '2026-01-31 19:05:39', '2026-01-31 19:05:39'),
(340, 'KRD', NULL, 'Kurundi Airport', NULL, 'AU', 'Northern Territory', -20.5100000, 134.6710000, 'active', '2026-01-31 19:05:39', '2026-01-31 19:05:39'),
(341, 'KTR', 'YPTN', 'RAAF Base Tindal', NULL, 'AU', 'Northern Territory', -14.5211000, 132.3780000, 'active', '2026-01-31 19:05:39', '2026-01-31 19:05:39'),
(342, 'LEL', 'YLEV', 'Lake Evella Airport', NULL, 'AU', 'Northern Territory', -12.4989000, 135.8060000, 'active', '2026-01-31 19:05:40', '2026-01-31 19:05:40'),
(343, 'LIB', NULL, 'Limbunya Airport', NULL, 'AU', 'Northern Territory', -17.2356000, 129.8820000, 'active', '2026-01-31 19:05:40', '2026-01-31 19:05:40'),
(344, 'LNH', 'YLKN', 'Lake Nash Airport', NULL, 'AU', 'Northern Territory', -20.9807000, 137.9180000, 'active', '2026-01-31 19:05:41', '2026-01-31 19:05:41'),
(345, 'MCV', 'YMHU', 'McArthur River Mine Airport', NULL, 'AU', 'Northern Territory', -16.4425000, 136.0840000, 'active', '2026-01-31 19:05:41', '2026-01-31 19:05:41'),
(346, 'MFP', 'YMCR', 'Manners Creek Airport', NULL, 'AU', 'Northern Territory', -22.1000000, 137.9830000, 'active', '2026-01-31 19:05:41', '2026-01-31 19:05:41'),
(347, 'MGT', 'YMGB', 'Milingimbi Airport', NULL, 'AU', 'Northern Territory', -12.0944000, 134.8940000, 'active', '2026-01-31 19:05:42', '2026-01-31 19:05:42'),
(348, 'MIY', NULL, 'Mittiebah Airport', NULL, 'AU', 'Northern Territory', -18.8093000, 137.0810000, 'active', '2026-01-31 19:05:42', '2026-01-31 19:05:42'),
(349, 'MIZ', NULL, 'Mainoru Airport', NULL, 'AU', 'Northern Territory', -14.0533000, 134.0940000, 'active', '2026-01-31 19:05:42', '2026-01-31 19:05:42'),
(350, 'MKV', 'YMVG', 'Mount Cavenagh Airport', NULL, 'AU', 'Northern Territory', -25.9667000, 133.2000000, 'active', '2026-01-31 19:05:43', '2026-01-31 19:05:43'),
(351, 'MNG', 'YMGD', 'Maningrida Airport', NULL, 'AU', 'Northern Territory', -12.0561000, 134.2340000, 'active', '2026-01-31 19:05:43', '2026-01-31 19:05:43'),
(352, 'MNV', NULL, 'Mount Valley Airport', NULL, 'AU', 'Northern Territory', -14.1167000, 133.8330000, 'active', '2026-01-31 19:05:43', '2026-01-31 19:05:43'),
(353, 'MNW', 'YMDS', 'MacDonald Downs Airport', NULL, 'AU', 'Northern Territory', -22.4440000, 135.1990000, 'active', '2026-01-31 19:05:44', '2026-01-31 19:05:44'),
(354, 'MQE', 'YMQA', 'Marqua Airport', NULL, 'AU', 'Northern Territory', -22.8058000, 137.2510000, 'active', '2026-01-31 19:05:44', '2026-01-31 19:05:44'),
(355, 'MRT', NULL, 'Moroak Airport', NULL, 'AU', 'Northern Territory', -14.8181000, 133.7010000, 'active', '2026-01-31 19:05:44', '2026-01-31 19:05:44'),
(356, 'MSF', 'YMNS', 'Mount Swan Airport', NULL, 'AU', 'Northern Territory', -22.6247000, 135.0350000, 'active', '2026-01-31 19:05:45', '2026-01-31 19:05:45'),
(357, 'MTD', 'YMSF', 'Mount Sandford Station Airport', NULL, 'AU', 'Northern Territory', -16.9783000, 130.5550000, 'active', '2026-01-31 19:05:45', '2026-01-31 19:05:45'),
(358, 'MUP', 'YMUP', 'Mulga Park Airport', NULL, 'AU', 'Northern Territory', -25.8600000, 131.6500000, 'active', '2026-01-31 19:05:45', '2026-01-31 19:05:45'),
(359, 'NPP', NULL, 'Napperby Airport', NULL, 'AU', 'Northern Territory', -22.5312000, 133.7630000, 'active', '2026-01-31 19:05:46', '2026-01-31 19:05:46'),
(360, 'NRY', NULL, 'Newry Airport', NULL, 'AU', 'Northern Territory', -16.0442000, 129.2640000, 'active', '2026-01-31 19:05:46', '2026-01-31 19:05:46'),
(361, 'NUB', 'YNUM', 'Numbulwar Airport', NULL, 'AU', 'Northern Territory', -14.2717000, 135.7170000, 'active', '2026-01-31 19:05:46', '2026-01-31 19:05:46'),
(362, 'PEP', NULL, 'Peppimenarti Airport', NULL, 'AU', 'Northern Territory', -14.1442000, 130.0910000, 'active', '2026-01-31 19:05:47', '2026-01-31 19:05:47'),
(363, 'PKT', 'YKPT', 'Port Keats Airfield', NULL, 'AU', 'Northern Territory', -14.2500000, 129.5290000, 'active', '2026-01-31 19:05:47', '2026-01-31 19:05:47'),
(364, 'RAM', 'YRNG', 'Ramingining Airport', NULL, 'AU', 'Northern Territory', -12.3564000, 134.8980000, 'active', '2026-01-31 19:05:48', '2026-01-31 19:05:48'),
(365, 'RDA', 'YRKD', 'Rockhampton Downs Airport', NULL, 'AU', 'Northern Territory', -18.9533000, 135.2010000, 'active', '2026-01-31 19:05:48', '2026-01-31 19:05:48'),
(366, 'RPB', 'YRRB', 'Roper Bar Airport', NULL, 'AU', 'Northern Territory', -14.7348000, 134.5250000, 'active', '2026-01-31 19:05:48', '2026-01-31 19:05:48'),
(367, 'RPM', 'YNGU', 'Ngukurr Airport', NULL, 'AU', 'Northern Territory', -14.7228000, 134.7470000, 'active', '2026-01-31 19:05:49', '2026-01-31 19:05:49'),
(368, 'RPV', NULL, 'Roper Valley Airport', NULL, 'AU', 'Northern Territory', -14.9215000, 134.0500000, 'active', '2026-01-31 19:05:49', '2026-01-31 19:05:49'),
(369, 'RRV', NULL, 'Robinson River Airport (Northern Territory)', NULL, 'AU', 'Northern Territory', -16.7183000, 136.9450000, 'active', '2026-01-31 19:05:49', '2026-01-31 19:05:49'),
(370, 'SHU', 'YSMP', 'Smith Point Airport', NULL, 'AU', 'Northern Territory', -11.1500000, 132.1500000, 'active', '2026-01-31 19:05:50', '2026-01-31 19:05:50'),
(371, 'SNB', 'YSNB', 'Snake Bay Airport', NULL, 'AU', 'Northern Territory', -11.4228000, 130.6540000, 'active', '2026-01-31 19:05:50', '2026-01-31 19:05:50'),
(372, 'TBK', 'YTBR', 'Timber Creek Airport', NULL, 'AU', 'Northern Territory', -15.6200000, 130.4450000, 'active', '2026-01-31 19:05:50', '2026-01-31 19:05:50'),
(373, 'TCA', 'YTNK', 'Tennant Creek Airport', NULL, 'AU', 'Northern Territory', -19.6344000, 134.1830000, 'active', '2026-01-31 19:05:51', '2026-01-31 19:05:51'),
(374, 'TYP', 'YTMY', 'Tobermorey Airport', NULL, 'AU', 'Northern Territory', -22.2558000, 137.9530000, 'active', '2026-01-31 19:05:51', '2026-01-31 19:05:51'),
(375, 'UTD', NULL, 'Nutwood Downs Airport', NULL, 'AU', 'Northern Territory', -15.8074000, 134.1460000, 'active', '2026-01-31 19:05:52', '2026-01-31 19:05:52'),
(376, 'VCD', 'YVRD', 'Victoria River Downs Airport', NULL, 'AU', 'Northern Territory', -16.4021000, 131.0050000, 'active', '2026-01-31 19:05:52', '2026-01-31 19:05:52'),
(377, 'WAV', 'YWAV', 'Wave Hill Airport', NULL, 'AU', 'Northern Territory', -17.3933000, 131.1180000, 'active', '2026-01-31 19:05:52', '2026-01-31 19:05:52'),
(378, 'WLL', 'YWOR', 'Wollogorang Airport', NULL, 'AU', 'Northern Territory', -17.2199000, 137.9350000, 'active', '2026-01-31 19:05:53', '2026-01-31 19:05:53'),
(379, 'WLO', 'YWTL', 'Waterloo Airport', NULL, 'AU', 'Northern Territory', -16.6300000, 129.3200000, 'active', '2026-01-31 19:05:53', '2026-01-31 19:05:53'),
(380, 'YUE', 'YYND', 'Yuendumu Airport', NULL, 'AU', 'Northern Territory', -22.2542000, 131.7820000, 'active', '2026-01-31 19:05:53', '2026-01-31 19:05:53'),
(381, 'AAB', 'YARY', 'Arrabury Airport', NULL, 'AU', 'Queensland', -26.6930000, 141.0480000, 'active', '2026-01-31 19:05:54', '2026-01-31 19:05:54'),
(382, 'ABG', 'YABI', 'Abingdon Airport', NULL, 'AU', 'Queensland', -17.6167000, 143.1670000, 'active', '2026-01-31 19:05:54', '2026-01-31 19:05:54'),
(383, 'ABH', 'YAPH', 'Alpha Airport', NULL, 'AU', 'Queensland', -23.6461000, 146.5840000, 'active', '2026-01-31 19:05:54', '2026-01-31 19:05:54'),
(384, 'ABM', 'YNPE', 'Northern Peninsula Airport', NULL, 'AU', 'Queensland', -10.9508000, 142.4590000, 'active', '2026-01-31 19:05:55', '2026-01-31 19:05:55'),
(385, 'AGW', NULL, 'Agnew Airport', NULL, 'AU', 'Queensland', -12.1456000, 142.1490000, 'active', '2026-01-31 19:05:55', '2026-01-31 19:05:55'),
(386, 'AUD', 'YAGD', 'Augustus Downs Airport', NULL, 'AU', 'Queensland', -18.5150000, 139.8780000, 'active', '2026-01-31 19:05:55', '2026-01-31 19:05:55'),
(387, 'AUU', 'YAUR', 'Aurukun Airport', NULL, 'AU', 'Queensland', -13.3541000, 141.7210000, 'active', '2026-01-31 19:05:56', '2026-01-31 19:05:56'),
(388, 'AXC', 'YAMC', 'Aramac Airport', NULL, 'AU', 'Queensland', -22.9667000, 145.2420000, 'active', '2026-01-31 19:05:56', '2026-01-31 19:05:56'),
(389, 'AYR', 'YAYR', 'Ayr Airport', NULL, 'AU', 'Queensland', -19.5844000, 147.3290000, 'active', '2026-01-31 19:05:56', '2026-01-31 19:05:56'),
(390, 'BBL', 'YLLE', 'Ballera Airport', NULL, 'AU', 'Queensland', -27.4056000, 141.8090000, 'active', '2026-01-31 19:05:57', '2026-01-31 19:05:57'),
(391, 'BCI', 'YBAR', 'Barcaldine Airport', NULL, 'AU', 'Queensland', -23.5653000, 145.3070000, 'active', '2026-01-31 19:05:57', '2026-01-31 19:05:57'),
(392, 'BCK', NULL, 'Bolwarra Airport', NULL, 'AU', 'Queensland', -17.3883000, 144.1690000, 'active', '2026-01-31 19:05:57', '2026-01-31 19:05:57'),
(393, 'BDB', 'YBUD', 'Bundaberg Airport', NULL, 'AU', 'Queensland', -24.9039000, 152.3190000, 'active', '2026-01-31 19:05:58', '2026-01-31 19:05:58'),
(394, 'BDD', 'YBAU', 'Badu Island Airport', NULL, 'AU', 'Queensland', -10.1500000, 142.1730000, 'active', '2026-01-31 19:05:58', '2026-01-31 19:05:58'),
(395, 'BEU', 'YBIE', 'Bedourie Airport', NULL, 'AU', 'Queensland', -24.3461000, 139.4600000, 'active', '2026-01-31 19:05:58', '2026-01-31 19:05:58'),
(396, 'BFC', NULL, 'Bloomfield Airport', NULL, 'AU', 'Queensland', -15.8736000, 145.3300000, 'active', '2026-01-31 19:05:59', '2026-01-31 19:05:59'),
(397, 'BHT', NULL, 'Brighton Downs Airport', NULL, 'AU', 'Queensland', -23.3639000, 141.5630000, 'active', '2026-01-31 19:05:59', '2026-01-31 19:05:59'),
(398, 'BIP', NULL, 'Bulimba Airport', NULL, 'AU', 'Queensland', -16.8808000, 143.4790000, 'active', '2026-01-31 19:06:00', '2026-01-31 19:06:00'),
(399, 'BKP', 'YBAW', 'Barkly Downs Airport', NULL, 'AU', 'Queensland', -20.4958000, 138.4750000, 'active', '2026-01-31 19:06:00', '2026-01-31 19:06:00'),
(400, 'BKQ', 'YBCK', 'Blackall Airport', NULL, 'AU', 'Queensland', -24.4278000, 145.4290000, 'active', '2026-01-31 19:06:00', '2026-01-31 19:06:00'),
(401, 'BLS', 'YBLL', 'Bollon Airport', NULL, 'AU', 'Queensland', -28.0583000, 147.4830000, 'active', '2026-01-31 19:06:01', '2026-01-31 19:06:01'),
(402, 'BLT', 'YBTR', 'Blackwater Airport', NULL, 'AU', 'Queensland', -23.6031000, 148.8070000, 'active', '2026-01-31 19:06:01', '2026-01-31 19:06:01'),
(403, 'BMP', 'YBPI', 'Brampton Island Airport', NULL, 'AU', 'Queensland', -20.8033000, 149.2700000, 'active', '2026-01-31 19:06:01', '2026-01-31 19:06:01'),
(404, 'BNE', 'YBBN', 'Brisbane Airport', NULL, 'AU', 'Queensland', -27.3842000, 153.1170000, 'active', '2026-01-31 19:06:02', '2026-01-31 19:06:02'),
(405, 'BQL', 'YBOU', 'Boulia Airport', NULL, 'AU', 'Queensland', -22.9133000, 139.9000000, 'active', '2026-01-31 19:06:02', '2026-01-31 19:06:02'),
(406, 'BTX', 'YBEO', 'Betoota Airport', NULL, 'AU', 'Queensland', -25.6417000, 140.7830000, 'active', '2026-01-31 19:06:02', '2026-01-31 19:06:02'),
(407, 'BUC', 'YBKT', 'Burketown Airport', NULL, 'AU', 'Queensland', -17.7486000, 139.5340000, 'active', '2026-01-31 19:06:03', '2026-01-31 19:06:03'),
(408, 'BVI', 'YBDV', 'Birdsville Airport', NULL, 'AU', 'Queensland', -25.8975000, 139.3480000, 'active', '2026-01-31 19:06:03', '2026-01-31 19:06:03'),
(409, 'BVW', NULL, 'Batavia Downs Airport', NULL, 'AU', 'Queensland', -12.6592000, 142.6750000, 'active', '2026-01-31 19:06:04', '2026-01-31 19:06:04'),
(410, 'BZP', NULL, 'Bizant Airport', NULL, 'AU', 'Queensland', -14.7403000, 144.1190000, 'active', '2026-01-31 19:06:04', '2026-01-31 19:06:04'),
(411, 'CBY', NULL, 'Canobie Airport', NULL, 'AU', 'Queensland', -19.4794000, 140.9270000, 'active', '2026-01-31 19:06:04', '2026-01-31 19:06:04'),
(412, 'CCL', 'YCCA', 'Chinchilla Airport', NULL, 'AU', 'Queensland', -26.7750000, 150.6170000, 'active', '2026-01-31 19:06:05', '2026-01-31 19:06:05'),
(413, 'CDQ', 'YCRY', 'Croydon Airport', NULL, 'AU', 'Queensland', -18.2250000, 142.2580000, 'active', '2026-01-31 19:06:05', '2026-01-31 19:06:05'),
(414, 'CFP', NULL, 'Carpentaria Downs Airport', NULL, 'AU', 'Queensland', -18.7167000, 144.3170000, 'active', '2026-01-31 19:06:05', '2026-01-31 19:06:05'),
(415, 'CMA', 'YCMU', 'Cunnamulla Airport', NULL, 'AU', 'Queensland', -28.0300000, 145.6220000, 'active', '2026-01-31 19:06:06', '2026-01-31 19:06:06'),
(416, 'CML', 'YCMW', 'Camooweal Airport', NULL, 'AU', 'Queensland', -19.9117000, 138.1250000, 'active', '2026-01-31 19:06:06', '2026-01-31 19:06:06'),
(417, 'CMQ', 'YCMT', 'Clermont Airport', NULL, 'AU', 'Queensland', -22.7731000, 147.6210000, 'active', '2026-01-31 19:06:06', '2026-01-31 19:06:06'),
(418, 'CNC', 'YCCT', 'Coconut Island Airport', NULL, 'AU', 'Queensland', -10.0500000, 143.0700000, 'active', '2026-01-31 19:06:07', '2026-01-31 19:06:07'),
(419, 'CNJ', 'YCCY', 'Cloncurry Airport', NULL, 'AU', 'Queensland', -20.6686000, 140.5040000, 'active', '2026-01-31 19:06:07', '2026-01-31 19:06:07'),
(420, 'CNS', 'YBCS', 'Cairns Airport', NULL, 'AU', 'Queensland', -16.8858000, 145.7550000, 'active', '2026-01-31 19:06:07', '2026-01-31 19:06:07'),
(421, 'CQP', NULL, 'Cape Flattery Airport', NULL, 'AU', 'Queensland', -14.9708000, 145.3120000, 'active', '2026-01-31 19:06:08', '2026-01-31 19:06:08'),
(422, 'CRH', NULL, 'Cherrabah Airport', NULL, 'AU', 'Queensland', -28.4301000, 152.0890000, 'active', '2026-01-31 19:06:08', '2026-01-31 19:06:08'),
(423, 'CTL', 'YBCV', 'Charleville Airport', NULL, 'AU', 'Queensland', -26.4133000, 146.2620000, 'active', '2026-01-31 19:06:09', '2026-01-31 19:06:09'),
(424, 'CTN', 'YCKN', 'Cooktown Airport', NULL, 'AU', 'Queensland', -15.4447000, 145.1840000, 'active', '2026-01-31 19:06:09', '2026-01-31 19:06:09'),
(425, 'CUD', 'YCDR', 'Caloundra Airport', NULL, 'AU', 'Queensland', -26.8000000, 153.1000000, 'active', '2026-01-31 19:06:09', '2026-01-31 19:06:09'),
(426, 'CUQ', 'YCOE', 'Coen Airport', NULL, 'AU', 'Queensland', -13.7611000, 143.1130000, 'active', '2026-01-31 19:06:10', '2026-01-31 19:06:10'),
(427, 'CXT', 'YCHT', 'Charters Towers Airport', NULL, 'AU', 'Queensland', -20.0431000, 146.2730000, 'active', '2026-01-31 19:06:10', '2026-01-31 19:06:10'),
(428, 'CZY', 'YUNY', 'Cluny Airport', NULL, 'AU', 'Queensland', -24.5167000, 139.6170000, 'active', '2026-01-31 19:06:10', '2026-01-31 19:06:10'),
(429, 'DBY', 'YDAY', 'Dalby Airport', NULL, 'AU', 'Queensland', -27.1553000, 151.2670000, 'active', '2026-01-31 19:06:11', '2026-01-31 19:06:11'),
(430, 'DDN', 'YDLT', 'Delta Downs Airport', NULL, 'AU', 'Queensland', -16.9917000, 141.3170000, 'active', '2026-01-31 19:06:11', '2026-01-31 19:06:11'),
(431, 'DFP', NULL, 'Drumduff Airport', NULL, 'AU', 'Queensland', -16.0530000, 143.0120000, 'active', '2026-01-31 19:06:11', '2026-01-31 19:06:11'),
(432, 'DHD', 'YDRH', 'Durham Downs Airport', NULL, 'AU', 'Queensland', -27.0750000, 141.9000000, 'active', '2026-01-31 19:06:12', '2026-01-31 19:06:12'),
(433, 'DKI', 'YDKI', 'Dunk Island Airport', NULL, 'AU', 'Queensland', -17.9417000, 146.1400000, 'active', '2026-01-31 19:06:12', '2026-01-31 19:06:12'),
(434, 'DMD', 'YDMG', 'Doomadgee Airport', NULL, 'AU', 'Queensland', -17.9403000, 138.8220000, 'active', '2026-01-31 19:06:12', '2026-01-31 19:06:12'),
(435, 'DNB', 'YDBR', 'Dunbar Airport', NULL, 'AU', 'Queensland', -16.0500000, 142.4000000, 'active', '2026-01-31 19:06:13', '2026-01-31 19:06:13'),
(436, 'DRD', 'YDOR', 'Dorunda Airport', NULL, 'AU', 'Queensland', -16.5537000, 141.8240000, 'active', '2026-01-31 19:06:13', '2026-01-31 19:06:13'),
(437, 'DRN', 'YDBI', 'Dirranbandi Airport', NULL, 'AU', 'Queensland', -28.5917000, 148.2170000, 'active', '2026-01-31 19:06:13', '2026-01-31 19:06:13'),
(438, 'DRR', 'YDRI', 'Durrie Airport', NULL, 'AU', 'Queensland', -25.6850000, 140.2280000, 'active', '2026-01-31 19:06:14', '2026-01-31 19:06:14'),
(439, 'DVP', 'YDPD', 'Davenport Downs Airport', NULL, 'AU', 'Queensland', -24.1500000, 141.1080000, 'active', '2026-01-31 19:06:14', '2026-01-31 19:06:14'),
(440, 'DXD', 'YDIX', 'Dixie Airport', NULL, 'AU', 'Queensland', -15.1175000, 143.3160000, 'active', '2026-01-31 19:06:14', '2026-01-31 19:06:14'),
(441, 'DYA', 'YDYS', 'Dysart Airport', NULL, 'AU', 'Queensland', -22.6222000, 148.3640000, 'active', '2026-01-31 19:06:15', '2026-01-31 19:06:15'),
(442, 'DYM', NULL, 'Diamantina Lakes Airport', NULL, 'AU', 'Queensland', -23.7617000, 141.1450000, 'active', '2026-01-31 19:06:15', '2026-01-31 19:06:15'),
(443, 'EDR', 'YPMP', 'Edward River Airport', NULL, 'AU', 'Queensland', -14.8965000, 141.6090000, 'active', '2026-01-31 19:06:15', '2026-01-31 19:06:15'),
(444, 'EIH', NULL, 'Einasleigh Airport', NULL, 'AU', 'Queensland', -18.5033000, 144.0940000, 'active', '2026-01-31 19:06:16', '2026-01-31 19:06:16'),
(445, 'EMD', 'YEML', 'Emerald Airport', NULL, 'AU', 'Queensland', -23.5675000, 148.1790000, 'active', '2026-01-31 19:06:16', '2026-01-31 19:06:16'),
(446, 'ERQ', 'YESE', 'Elrose Airport', NULL, 'AU', 'Queensland', -20.9764000, 141.0070000, 'active', '2026-01-31 19:06:17', '2026-01-31 19:06:17'),
(447, 'GAH', 'YGAY', 'Gayndah Airport', NULL, 'AU', 'Queensland', -25.6144000, 151.6190000, 'active', '2026-01-31 19:06:17', '2026-01-31 19:06:17'),
(448, 'GBP', 'YGAM', 'Gamboola Airport', NULL, 'AU', 'Queensland', -16.5500000, 143.6670000, 'active', '2026-01-31 19:06:17', '2026-01-31 19:06:17'),
(449, 'GGD', 'YGDS', 'Gregory Downs Airport', NULL, 'AU', 'Queensland', -18.6250000, 139.2330000, 'active', '2026-01-31 19:06:18', '2026-01-31 19:06:18'),
(450, 'GIC', 'YBOI', 'Boigu Island Airport', NULL, 'AU', 'Queensland', -9.2327800, 142.2180000, 'active', '2026-01-31 19:06:18', '2026-01-31 19:06:18'),
(451, 'GKL', 'YGKL', 'Great Keppel Island Airport', NULL, 'AU', 'Queensland', -23.1833000, 150.9420000, 'active', '2026-01-31 19:06:18', '2026-01-31 19:06:18'),
(452, 'GLG', 'YGLE', 'Glengyle Airport', NULL, 'AU', 'Queensland', -24.8083000, 139.6000000, 'active', '2026-01-31 19:06:19', '2026-01-31 19:06:19'),
(453, 'GLM', 'YGLO', 'Glenormiston Airport', NULL, 'AU', 'Queensland', -22.8883000, 138.8250000, 'active', '2026-01-31 19:06:19', '2026-01-31 19:06:19'),
(454, 'GLT', 'YGLA', 'Gladstone Airport', NULL, 'AU', 'Queensland', -23.8697000, 151.2230000, 'active', '2026-01-31 19:06:19', '2026-01-31 19:06:19'),
(455, 'GOO', 'YGDI', 'Goondiwindi Airport', NULL, 'AU', 'Queensland', -28.5214000, 150.3200000, 'active', '2026-01-31 19:06:20', '2026-01-31 19:06:20'),
(456, 'GPD', 'YGON', 'Mount Gordon Airport', NULL, 'AU', 'Queensland', -19.7726000, 139.4040000, 'active', '2026-01-31 19:06:20', '2026-01-31 19:06:20'),
(457, 'GTT', 'YGTN', 'Georgetown Airport', NULL, 'AU', 'Queensland', -18.3050000, 143.5300000, 'active', '2026-01-31 19:06:21', '2026-01-31 19:06:21'),
(458, 'GVP', 'YGNV', 'Greenvale Airport', NULL, 'AU', 'Queensland', -18.9966000, 145.0140000, 'active', '2026-01-31 19:06:21', '2026-01-31 19:06:21'),
(459, 'GYP', 'YGYM', 'Gympie Airport', NULL, 'AU', 'Queensland', -26.2828000, 152.7020000, 'active', '2026-01-31 19:06:21', '2026-01-31 19:06:21'),
(460, 'HAT', 'YHTL', 'Heathlands Airport', NULL, 'AU', 'Queensland', -11.7369000, 142.5770000, 'active', '2026-01-31 19:06:22', '2026-01-31 19:06:22'),
(461, 'HGD', 'YHUG', 'Hughenden Airport', NULL, 'AU', 'Queensland', -20.8150000, 144.2250000, 'active', '2026-01-31 19:06:22', '2026-01-31 19:06:22'),
(462, 'HID', 'YHID', 'Horn Island Airport', NULL, 'AU', 'Queensland', -10.5864000, 142.2900000, 'active', '2026-01-31 19:06:22', '2026-01-31 19:06:22'),
(463, 'HIG', 'YHHY', 'Highbury Airport', NULL, 'AU', 'Queensland', -16.4244000, 143.1460000, 'active', '2026-01-31 19:06:23', '2026-01-31 19:06:23'),
(464, 'HIP', 'YHDY', 'Headingly Airport', NULL, 'AU', 'Queensland', -21.3333000, 138.2830000, 'active', '2026-01-31 19:06:23', '2026-01-31 19:06:23'),
(465, 'HLV', NULL, 'Helenvale Airport', NULL, 'AU', 'Queensland', -15.6858000, 145.2150000, 'active', '2026-01-31 19:06:23', '2026-01-31 19:06:23'),
(466, 'HPE', NULL, 'Hopevale Airport', NULL, 'AU', 'Queensland', -15.2923000, 145.1040000, 'active', '2026-01-31 19:06:24', '2026-01-31 19:06:24'),
(467, 'HTI', 'YBHM', 'Great Barrier Reef Airport', NULL, 'AU', 'Queensland', -20.3581000, 148.9520000, 'active', '2026-01-31 19:06:24', '2026-01-31 19:06:24'),
(468, 'HVB', 'YHBA', 'Hervey Bay Airport', NULL, 'AU', 'Queensland', -25.3189000, 152.8800000, 'active', '2026-01-31 19:06:24', '2026-01-31 19:06:24'),
(469, 'IFF', 'YIFY', 'Iffley Airport', NULL, 'AU', 'Queensland', -18.9000000, 141.2170000, 'active', '2026-01-31 19:06:25', '2026-01-31 19:06:25'),
(470, 'IFL', 'YIFL', 'Innisfail Airport', NULL, 'AU', 'Queensland', -17.5594000, 146.0120000, 'active', '2026-01-31 19:06:25', '2026-01-31 19:06:25'),
(471, 'IGH', 'YIGM', 'Ingham Airport', NULL, 'AU', 'Queensland', -18.6606000, 146.1520000, 'active', '2026-01-31 19:06:25', '2026-01-31 19:06:25'),
(472, 'IKP', 'YIKM', 'Inkerman Airport', NULL, 'AU', 'Queensland', -16.2750000, 141.4420000, 'active', '2026-01-31 19:06:26', '2026-01-31 19:06:26'),
(473, 'INJ', 'YINJ', 'Injune Airport', NULL, 'AU', 'Queensland', -25.8510000, 148.5500000, 'active', '2026-01-31 19:06:26', '2026-01-31 19:06:26'),
(474, 'IRG', 'YLHR', 'Lockhart River Airport', NULL, 'AU', 'Queensland', -12.7869000, 143.3050000, 'active', '2026-01-31 19:06:26', '2026-01-31 19:06:26'),
(475, 'ISA', 'YBMA', 'Mount Isa Airport', NULL, 'AU', 'Queensland', -20.6639000, 139.4890000, 'active', '2026-01-31 19:06:27', '2026-01-31 19:06:27'),
(476, 'ISI', 'YISF', 'Isisford Airport', NULL, 'AU', 'Queensland', -24.2583000, 144.4250000, 'active', '2026-01-31 19:06:27', '2026-01-31 19:06:27'),
(477, 'JCK', 'YJLC', 'Julia Creek Airport', NULL, 'AU', 'Queensland', -20.6683000, 141.7230000, 'active', '2026-01-31 19:06:27', '2026-01-31 19:06:27'),
(478, 'JUN', 'YJDA', 'Jundah Airport', NULL, 'AU', 'Queensland', -24.8417000, 143.0580000, 'active', '2026-01-31 19:06:28', '2026-01-31 19:06:28'),
(479, 'KCE', 'YCSV', 'Collinsville Airport', NULL, 'AU', 'Queensland', -20.5967000, 147.8600000, 'active', '2026-01-31 19:06:28', '2026-01-31 19:06:28'),
(480, 'KDS', NULL, 'Kamaran Downs Airport', NULL, 'AU', 'Queensland', -24.3388000, 139.2790000, 'active', '2026-01-31 19:06:28', '2026-01-31 19:06:28'),
(481, 'KGY', 'YKRY', 'Kingaroy Airport', NULL, 'AU', 'Queensland', -26.5808000, 151.8410000, 'active', '2026-01-31 19:06:29', '2026-01-31 19:06:29'),
(482, 'KKP', 'YKLB', 'Koolburra Airport', NULL, 'AU', 'Queensland', -15.3189000, 143.9550000, 'active', '2026-01-31 19:06:29', '2026-01-31 19:06:29'),
(483, 'KML', 'YKML', 'Kamileroi Airport', NULL, 'AU', 'Queensland', -19.3750000, 140.0570000, 'active', '2026-01-31 19:06:29', '2026-01-31 19:06:29'),
(484, 'KOH', 'YKLA', 'Koolatah Airport', NULL, 'AU', 'Queensland', -15.8886000, 142.4390000, 'active', '2026-01-31 19:06:30', '2026-01-31 19:06:30'),
(485, 'KPP', 'YKPR', 'Kalpowar Airport', NULL, 'AU', 'Queensland', -14.8900000, 144.2200000, 'active', '2026-01-31 19:06:30', '2026-01-31 19:06:30'),
(486, 'KRB', 'YKMB', 'Karumba Airport', NULL, 'AU', 'Queensland', -17.4567000, 140.8300000, 'active', '2026-01-31 19:06:30', '2026-01-31 19:06:30'),
(487, 'KSV', 'YSPV', 'Springvale Airport', NULL, 'AU', 'Queensland', -23.5500000, 140.7000000, 'active', '2026-01-31 19:06:31', '2026-01-31 19:06:31'),
(488, 'KUG', 'YKUB', 'Kubin Airport', NULL, 'AU', 'Queensland', -10.2250000, 142.2180000, 'active', '2026-01-31 19:06:31', '2026-01-31 19:06:31'),
(489, 'KWM', 'YKOW', 'Kowanyama Airport', NULL, 'AU', 'Queensland', -15.4856000, 141.7510000, 'active', '2026-01-31 19:06:31', '2026-01-31 19:06:31'),
(490, 'LDC', 'YLIN', 'Lindeman Island Airport', NULL, 'AU', 'Queensland', -20.4536000, 149.0400000, 'active', '2026-01-31 19:06:32', '2026-01-31 19:06:32'),
(491, 'LFP', 'YLFD', 'Lakefield Airport', NULL, 'AU', 'Queensland', -14.9207000, 144.2030000, 'active', '2026-01-31 19:06:32', '2026-01-31 19:06:32'),
(492, 'LKD', 'YLND', 'Lakeland Downs Airport', NULL, 'AU', 'Queensland', -15.8333000, 144.8500000, 'active', '2026-01-31 19:06:32', '2026-01-31 19:06:32'),
(493, 'LLG', 'YCGO', 'Chillagoe Airport', NULL, 'AU', 'Queensland', -17.1428000, 144.5290000, 'active', '2026-01-31 19:06:33', '2026-01-31 19:06:33'),
(494, 'LLP', NULL, 'Linda Downs Airport', NULL, 'AU', 'Queensland', -23.0167000, 138.7000000, 'active', '2026-01-31 19:06:33', '2026-01-31 19:06:33'),
(495, 'LOA', 'YLOR', 'Lorraine Airport', NULL, 'AU', 'Queensland', -18.9933000, 139.9070000, 'active', '2026-01-31 19:06:34', '2026-01-31 19:06:34'),
(496, 'LRE', 'YLRE', 'Longreach Airport', NULL, 'AU', 'Queensland', -23.4342000, 144.2800000, 'active', '2026-01-31 19:06:34', '2026-01-31 19:06:34'),
(497, 'LTP', 'YLHS', 'Lyndhurst Airport', NULL, 'AU', 'Queensland', -19.1958000, 144.3710000, 'active', '2026-01-31 19:06:34', '2026-01-31 19:06:34'),
(498, 'LTV', 'YLOV', 'Lotus Vale Station Airport', NULL, 'AU', 'Queensland', -17.0483000, 141.3760000, 'active', '2026-01-31 19:06:35', '2026-01-31 19:06:35'),
(499, 'LUT', 'YLRS', 'New Laura Airport', NULL, 'AU', 'Queensland', -15.1833000, 144.3670000, 'active', '2026-01-31 19:06:35', '2026-01-31 19:06:35'),
(500, 'LUU', 'YLRA', 'Laura Airport', NULL, 'AU', 'Queensland', -15.5500000, 144.4500000, 'active', '2026-01-31 19:06:35', '2026-01-31 19:06:35'),
(501, 'LWH', 'YLAH', 'Lawn Hill Airport', NULL, 'AU', 'Queensland', -18.5683000, 138.6350000, 'active', '2026-01-31 19:06:36', '2026-01-31 19:06:36'),
(502, 'LYT', NULL, 'Lady Elliot Island Airport', NULL, 'AU', 'Queensland', -24.1129000, 152.7160000, 'active', '2026-01-31 19:06:36', '2026-01-31 19:06:36'),
(503, 'LZR', 'YLZI', 'Lizard Island Airport', NULL, 'AU', 'Queensland', -14.6733000, 145.4550000, 'active', '2026-01-31 19:06:36', '2026-01-31 19:06:36'),
(504, 'MBH', 'YMYB', 'Maryborough Airport', NULL, 'AU', 'Queensland', -25.5133000, 152.7150000, 'active', '2026-01-31 19:06:37', '2026-01-31 19:06:37'),
(505, 'MCY', 'YBSU', 'Sunshine Coast Airport', NULL, 'AU', 'Queensland', -26.6033000, 153.0910000, 'active', '2026-01-31 19:06:37', '2026-01-31 19:06:37'),
(506, 'MET', 'YMOT', 'Moreton Airport', NULL, 'AU', 'Queensland', -12.4442000, 142.6380000, 'active', '2026-01-31 19:06:37', '2026-01-31 19:06:37'),
(507, 'MFL', NULL, 'Mount Full Stop Airport', NULL, 'AU', 'Queensland', -19.6700000, 144.8850000, 'active', '2026-01-31 19:06:38', '2026-01-31 19:06:38'),
(508, 'MKY', 'YBMK', 'Mackay Airport', NULL, 'AU', 'Queensland', -21.1717000, 149.1800000, 'active', '2026-01-31 19:06:38', '2026-01-31 19:06:38'),
(509, 'MLV', 'YMEU', 'Merluna Airport', NULL, 'AU', 'Queensland', -13.0649000, 142.4540000, 'active', '2026-01-31 19:06:38', '2026-01-31 19:06:38'),
(510, 'MMM', 'YMMU', 'Middlemount Airport', NULL, 'AU', 'Queensland', -22.8025000, 148.7050000, 'active', '2026-01-31 19:06:39', '2026-01-31 19:06:39'),
(511, 'MNQ', 'YMTO', 'Monto Airport', NULL, 'AU', 'Queensland', -24.8858000, 151.1000000, 'active', '2026-01-31 19:06:39', '2026-01-31 19:06:39'),
(512, 'MOV', 'YMRB', 'Moranbah Airport', NULL, 'AU', 'Queensland', -22.0578000, 148.0770000, 'active', '2026-01-31 19:06:40', '2026-01-31 19:06:40'),
(513, 'MRG', 'YMBA', 'Mareeba Airfield', NULL, 'AU', 'Queensland', -17.0692000, 145.4190000, 'active', '2026-01-31 19:06:40', '2026-01-31 19:06:40'),
(514, 'MRL', NULL, 'Miners Lake Airport', NULL, 'AU', 'Queensland', 46.3834000, -82.6331000, 'active', '2026-01-31 19:06:40', '2026-01-31 19:06:40'),
(515, 'MTQ', 'YMIT', 'Mitchell Airport', NULL, 'AU', 'Queensland', -26.4833000, 147.9370000, 'active', '2026-01-31 19:06:41', '2026-01-31 19:06:41'),
(516, 'MVU', 'YMGV', 'Musgrave Airport', NULL, 'AU', 'Queensland', -14.7757000, 143.5050000, 'active', '2026-01-31 19:06:41', '2026-01-31 19:06:41'),
(517, 'MWY', 'YMIR', 'Miranda Downs Airport', NULL, 'AU', 'Queensland', -17.3289000, 141.8860000, 'active', '2026-01-31 19:06:41', '2026-01-31 19:06:41'),
(518, 'MXD', 'YMWX', 'Marion Downs Airport', NULL, 'AU', 'Queensland', -23.3637000, 139.6500000, 'active', '2026-01-31 19:06:42', '2026-01-31 19:06:42'),
(519, 'MYI', 'YMAE', 'Murray Island Airport', NULL, 'AU', 'Queensland', -9.9166700, 144.0550000, 'active', '2026-01-31 19:06:42', '2026-01-31 19:06:42'),
(520, 'NLF', 'YDNI', 'Darnley Island Airport', NULL, 'AU', 'Queensland', -9.5833300, 143.7670000, 'active', '2026-01-31 19:06:42', '2026-01-31 19:06:42'),
(521, 'NMP', NULL, 'New Moon Airport', NULL, 'AU', 'Queensland', -19.2000000, 145.7730000, 'active', '2026-01-31 19:06:43', '2026-01-31 19:06:43'),
(522, 'NMR', 'YNAP', 'Nappa Merrie Airport', NULL, 'AU', 'Queensland', -27.5583000, 141.1330000, 'active', '2026-01-31 19:06:43', '2026-01-31 19:06:43'),
(523, 'NSV', 'YNSH', 'Noosa Airport', NULL, 'AU', 'Queensland', -26.4233000, 153.0630000, 'active', '2026-01-31 19:06:44', '2026-01-31 19:06:44'),
(524, 'NTN', 'YNTN', 'Normanton Airport', NULL, 'AU', 'Queensland', -17.6841000, 141.0700000, 'active', '2026-01-31 19:06:44', '2026-01-31 19:06:44'),
(525, 'OBA', NULL, 'Oban Airport', NULL, 'AU', 'Queensland', 56.4657000, -5.3977000, 'active', '2026-01-31 19:06:44', '2026-01-31 19:06:44'),
(526, 'OKB', 'YORC', 'Orchid Beach Airport', NULL, 'AU', 'Queensland', -24.9594000, 153.3150000, 'active', '2026-01-31 19:06:45', '2026-01-31 19:06:45'),
(527, 'OKR', 'YYKI', 'Yorke Island Airport', NULL, 'AU', 'Queensland', -9.7528000, 143.4060000, 'active', '2026-01-31 19:06:45', '2026-01-31 19:06:45'),
(528, 'OKY', 'YBOK', 'Oakey Army Aviation Centre', NULL, 'AU', 'Queensland', -27.4114000, 151.7350000, 'active', '2026-01-31 19:06:45', '2026-01-31 19:06:45'),
(529, 'ONG', 'YMTI', 'Mornington Island Airport', NULL, 'AU', 'Queensland', -16.6625000, 139.1780000, 'active', '2026-01-31 19:06:46', '2026-01-31 19:06:46'),
(530, 'ONR', 'YMNK', 'Monkira Airport', NULL, 'AU', 'Queensland', -24.8167000, 140.5330000, 'active', '2026-01-31 19:06:46', '2026-01-31 19:06:46'),
(531, 'OOL', 'YBCG', 'Gold Coast Airport (Coolangatta Airport)', NULL, 'AU', 'Queensland', -28.1644000, 153.5050000, 'active', '2026-01-31 19:06:46', '2026-01-31 19:06:46'),
(532, 'OOR', 'YMOO', 'Mooraberree Airport', NULL, 'AU', 'Queensland', -25.2500000, 140.9830000, 'active', '2026-01-31 19:06:47', '2026-01-31 19:06:47'),
(533, 'OPI', 'YOEN', 'Oenpelli Airport', NULL, 'AU', 'Queensland', -12.3250000, 133.0060000, 'active', '2026-01-31 19:06:47', '2026-01-31 19:06:47'),
(534, 'ORS', NULL, 'Orpheus Island Resort Waterport', NULL, 'AU', 'Queensland', -18.6340000, 146.5000000, 'active', '2026-01-31 19:06:47', '2026-01-31 19:06:47'),
(535, 'OSO', 'YOSB', 'Osborne Mine Airport', NULL, 'AU', 'Queensland', -22.0817000, 140.5550000, 'active', '2026-01-31 19:06:48', '2026-01-31 19:06:48'),
(536, 'OXO', NULL, 'Orientos Airport', NULL, 'AU', 'Queensland', -28.0598000, 141.5360000, 'active', '2026-01-31 19:06:48', '2026-01-31 19:06:48'),
(537, 'OXY', 'YMNY', 'Morney Airport', NULL, 'AU', 'Queensland', -25.3583000, 141.4330000, 'active', '2026-01-31 19:06:48', '2026-01-31 19:06:48'),
(538, 'PHQ', 'YTMO', 'The Monument Airport', NULL, 'AU', 'Queensland', -21.8111000, 139.9240000, 'active', '2026-01-31 19:06:49', '2026-01-31 19:06:49'),
(539, 'PMK', 'YPAM', 'Palm Island Airport', NULL, 'AU', 'Queensland', -18.7553000, 146.5810000, 'active', '2026-01-31 19:06:49', '2026-01-31 19:06:49'),
(540, 'PPP', 'YBPN', 'Whitsunday Coast Airport', NULL, 'AU', 'Queensland', -20.4950000, 148.5520000, 'active', '2026-01-31 19:06:49', '2026-01-31 19:06:49'),
(541, 'RCM', 'YRMD', 'Richmond Airport', NULL, 'AU', 'Queensland', -20.7019000, 143.1150000, 'active', '2026-01-31 19:06:50', '2026-01-31 19:06:50'),
(542, 'RKY', NULL, 'Rokeby Airport', NULL, 'AU', 'Queensland', -13.6434000, 142.6410000, 'active', '2026-01-31 19:06:50', '2026-01-31 19:06:50'),
(543, 'RLP', NULL, 'Rosella Plains Airport', NULL, 'AU', 'Queensland', -18.4253000, 144.4590000, 'active', '2026-01-31 19:06:50', '2026-01-31 19:06:50'),
(544, 'RMA', 'YROM', 'Roma Airport', NULL, 'AU', 'Queensland', -26.5450000, 148.7750000, 'active', '2026-01-31 19:06:51', '2026-01-31 19:06:51'),
(545, 'ROH', 'YROB', 'Robinhood Airport', NULL, 'AU', 'Queensland', -18.8450000, 143.7100000, 'active', '2026-01-31 19:06:51', '2026-01-31 19:06:51'),
(546, 'ROK', 'YBRK', 'Rockhampton Airport', NULL, 'AU', 'Queensland', -23.3819000, 150.4750000, 'active', '2026-01-31 19:06:51', '2026-01-31 19:06:51'),
(547, 'RSB', 'YRSB', 'Roseberth Airport', NULL, 'AU', 'Queensland', -25.8333000, 139.6500000, 'active', '2026-01-31 19:06:52', '2026-01-31 19:06:52'),
(548, 'RTP', 'YRTP', 'Rutland Plains Airport', NULL, 'AU', 'Queensland', -15.6433000, 141.8430000, 'active', '2026-01-31 19:06:52', '2026-01-31 19:06:52'),
(549, 'SBR', 'YSII', 'Saibai Island Airport', NULL, 'AU', 'Queensland', -9.3783300, 142.6250000, 'active', '2026-01-31 19:06:53', '2026-01-31 19:06:53'),
(550, 'SCG', 'YSPK', 'Spring Creek Airport', NULL, 'AU', 'Queensland', -18.6333000, 144.5670000, 'active', '2026-01-31 19:06:53', '2026-01-31 19:06:53'),
(551, 'SGO', 'YSGE', 'St George Airport', NULL, 'AU', 'Queensland', -28.0497000, 148.5950000, 'active', '2026-01-31 19:06:53', '2026-01-31 19:06:53'),
(552, 'SHQ', 'YSPT', 'Southport Airport', NULL, 'AU', 'Queensland', -27.9221000, 153.3720000, 'active', '2026-01-31 19:06:54', '2026-01-31 19:06:54'),
(553, 'SNH', 'YSPE', 'Stanthorpe Airport', NULL, 'AU', 'Queensland', -28.6203000, 151.9910000, 'active', '2026-01-31 19:06:54', '2026-01-31 19:06:54'),
(554, 'SRM', NULL, 'Sandringham Station Airport', NULL, 'AU', 'Queensland', -24.0568000, 139.0820000, 'active', '2026-01-31 19:06:54', '2026-01-31 19:06:54'),
(555, 'SRR', NULL, 'Dunwich Airport', NULL, 'AU', 'Queensland', -27.5167000, 153.4280000, 'active', '2026-01-31 19:06:55', '2026-01-31 19:06:55'),
(556, 'SSP', NULL, 'Silver Plains Airport', NULL, 'AU', 'Queensland', -13.9754000, 143.5540000, 'active', '2026-01-31 19:06:55', '2026-01-31 19:06:55'),
(557, 'STF', 'YSTI', 'Stephens Island Airport', NULL, 'AU', 'Queensland', -9.5100000, 143.5500000, 'active', '2026-01-31 19:06:55', '2026-01-31 19:06:55'),
(558, 'STH', 'YSMR', 'Strathmore Airport', NULL, 'AU', 'Queensland', -17.8500000, 142.5670000, 'active', '2026-01-31 19:06:56', '2026-01-31 19:06:56'),
(559, 'SVM', NULL, 'St Pauls Mission Airport', NULL, 'AU', 'Queensland', -10.3667000, 142.1170000, 'active', '2026-01-31 19:06:56', '2026-01-31 19:06:56'),
(560, 'SYU', 'YWBS', 'Warraber Island Airport', NULL, 'AU', 'Queensland', -10.2083000, 142.8250000, 'active', '2026-01-31 19:06:56', '2026-01-31 19:06:56'),
(561, 'TAN', 'YTGA', 'Tangalooma Airport', NULL, 'AU', 'Queensland', -27.1300000, 153.3630000, 'active', '2026-01-31 19:06:57', '2026-01-31 19:06:57'),
(562, 'TDR', 'YTDR', 'Theodore Airport', NULL, 'AU', 'Queensland', -24.9933000, 150.0930000, 'active', '2026-01-31 19:06:57', '2026-01-31 19:06:57'),
(563, 'THG', 'YTNG', 'Thangool Airport', NULL, 'AU', 'Queensland', -24.4939000, 150.5760000, 'active', '2026-01-31 19:06:57', '2026-01-31 19:06:57'),
(564, 'TQP', 'YTEE', 'Trepell Airport', NULL, 'AU', 'Queensland', -21.8350000, 140.8880000, 'active', '2026-01-31 19:06:58', '2026-01-31 19:06:58'),
(565, 'TSV', 'YBTL', 'Townsville Airport', NULL, 'AU', 'Queensland', -19.2525000, 146.7650000, 'active', '2026-01-31 19:06:58', '2026-01-31 19:06:58'),
(566, 'TWB', 'YTWB', 'Toowoomba City Aerodrome', NULL, 'AU', 'Queensland', -27.5428000, 151.9160000, 'active', '2026-01-31 19:06:58', '2026-01-31 19:06:58'),
(567, 'TWN', NULL, 'Tewantin Airport', NULL, 'AU', 'Queensland', -26.3880000, 153.0280000, 'active', '2026-01-31 19:06:59', '2026-01-31 19:06:59'),
(568, 'TWP', NULL, 'Torwood Airport', NULL, 'AU', 'Queensland', -17.3633000, 143.7500000, 'active', '2026-01-31 19:06:59', '2026-01-31 19:06:59'),
(569, 'TXR', NULL, 'Tanbar Airport', NULL, 'AU', 'Queensland', -25.8478000, 141.9280000, 'active', '2026-01-31 19:06:59', '2026-01-31 19:06:59'),
(570, 'TYG', 'YTHY', 'Thylungra Airport', NULL, 'AU', 'Queensland', -26.0833000, 143.4670000, 'active', '2026-01-31 19:07:00', '2026-01-31 19:07:00'),
(571, 'UBB', 'YMAA', 'Mabuiag Island Airport', NULL, 'AU', 'Queensland', -9.9500000, 142.1830000, 'active', '2026-01-31 19:07:00', '2026-01-31 19:07:00'),
(572, 'UDA', 'YUDA', 'Undara Airport', NULL, 'AU', 'Queensland', -18.2000000, 144.6000000, 'active', '2026-01-31 19:07:00', '2026-01-31 19:07:00'),
(573, 'ULP', 'YQLP', 'Quilpie Airport', NULL, 'AU', 'Queensland', -26.6122000, 144.2530000, 'active', '2026-01-31 19:07:01', '2026-01-31 19:07:01'),
(574, 'UTB', 'YMTB', 'Muttaburra Airport', NULL, 'AU', 'Queensland', -22.5833000, 144.5330000, 'active', '2026-01-31 19:07:01', '2026-01-31 19:07:01'),
(575, 'VNR', 'YVRS', 'Vanrook Airport', NULL, 'AU', 'Queensland', -16.9633000, 141.9500000, 'active', '2026-01-31 19:07:01', '2026-01-31 19:07:01'),
(576, 'WAN', NULL, 'Waverney Airport', NULL, 'AU', 'Queensland', -25.3563000, 141.9250000, 'active', '2026-01-31 19:07:02', '2026-01-31 19:07:02'),
(577, 'WAZ', 'YWCK', 'Warwick Airport', NULL, 'AU', 'Queensland', -28.1494000, 151.9430000, 'active', '2026-01-31 19:07:02', '2026-01-31 19:07:02'),
(578, 'WDI', 'YWND', 'Wondai Airport', NULL, 'AU', 'Queensland', -26.2833000, 151.8580000, 'active', '2026-01-31 19:07:02', '2026-01-31 19:07:02'),
(579, 'WEI', 'YBWP', 'Weipa Airport', NULL, 'AU', 'Queensland', -12.6786000, 141.9250000, 'active', '2026-01-31 19:07:03', '2026-01-31 19:07:03'),
(580, 'WIN', 'YWTN', 'Winton Airport', NULL, 'AU', 'Queensland', -22.3636000, 143.0860000, 'active', '2026-01-31 19:07:03', '2026-01-31 19:07:03'),
(581, 'WLE', 'YMLS', 'Miles Airport', NULL, 'AU', 'Queensland', -26.8083000, 150.1750000, 'active', '2026-01-31 19:07:03', '2026-01-31 19:07:03'),
(582, 'WNR', 'YWDH', 'Windorah Airport', NULL, 'AU', 'Queensland', -25.4131000, 142.6670000, 'active', '2026-01-31 19:07:04', '2026-01-31 19:07:04'),
(583, 'WON', 'YWDL', 'Wondoola Airport', NULL, 'AU', 'Queensland', -18.5750000, 140.8920000, 'active', '2026-01-31 19:07:04', '2026-01-31 19:07:04'),
(584, 'WPK', 'YWMP', 'Wrotham Park Airport', NULL, 'AU', 'Queensland', -16.6583000, 144.0020000, 'active', '2026-01-31 19:07:04', '2026-01-31 19:07:04'),
(585, 'WSY', 'YSHR', 'Whitsunday Airport', NULL, 'AU', 'Queensland', -20.2761000, 148.7550000, 'active', '2026-01-31 19:07:05', '2026-01-31 19:07:05'),
(586, 'WTB', 'YBWW', 'Toowoomba Wellcamp Airport', NULL, 'AU', 'Queensland', -27.5583000, 151.7930000, 'active', '2026-01-31 19:07:05', '2026-01-31 19:07:05'),
(587, 'XMY', 'YYMI', 'Yam Island Airport', NULL, 'AU', 'Queensland', -9.9011100, 142.7760000, 'active', '2026-01-31 19:07:05', '2026-01-31 19:07:05'),
(588, 'XTG', 'YTGM', 'Thargomindah Airport', NULL, 'AU', 'Queensland', -27.9864000, 143.8110000, 'active', '2026-01-31 19:07:06', '2026-01-31 19:07:06'),
(589, 'XTO', 'YTAM', 'Taroom Airport', NULL, 'AU', 'Queensland', -25.8017000, 149.9000000, 'active', '2026-01-31 19:07:06', '2026-01-31 19:07:06'),
(590, 'XTR', 'YTAA', 'Tara Airport', NULL, 'AU', 'Queensland', -27.1567000, 150.4770000, 'active', '2026-01-31 19:07:06', '2026-01-31 19:07:06'),
(591, 'ZBL', NULL, 'Biloela Airport', NULL, 'AU', 'Queensland', -24.4000000, 150.5100000, 'active', '2026-01-31 19:07:07', '2026-01-31 19:07:07'),
(592, 'ZBO', 'YBWN', 'Bowen Airport', NULL, 'AU', 'Queensland', -20.0183000, 148.2150000, 'active', '2026-01-31 19:07:07', '2026-01-31 19:07:07'),
(593, 'ZGL', 'YSGW', 'South Galway Airport', NULL, 'AU', 'Queensland', -25.6833000, 142.1080000, 'active', '2026-01-31 19:07:08', '2026-01-31 19:07:08'),
(594, 'ADL', 'YPAD', 'Adelaide Airport', NULL, 'AU', 'South Australia', -34.9450000, 138.5310000, 'active', '2026-01-31 19:07:08', '2026-01-31 19:07:08'),
(595, 'ADO', 'YAMK', 'Andamooka Airport', NULL, 'AU', 'South Australia', -30.4383000, 137.1370000, 'active', '2026-01-31 19:07:08', '2026-01-31 19:07:08'),
(596, 'AMT', 'YAMT', 'Amata Airport', NULL, 'AU', 'South Australia', -26.1083000, 131.2070000, 'active', '2026-01-31 19:07:09', '2026-01-31 19:07:09'),
(597, 'AWN', NULL, 'Alton Downs Airport', NULL, 'AU', 'South Australia', -26.5333000, 139.2670000, 'active', '2026-01-31 19:07:09', '2026-01-31 19:07:09'),
(598, 'CCW', 'YCWL', 'Cowell Airport', NULL, 'AU', 'South Australia', -33.6667000, 136.8920000, 'active', '2026-01-31 19:07:09', '2026-01-31 19:07:09'),
(599, 'CED', 'YCDU', 'Ceduna Airport', NULL, 'AU', 'South Australia', -32.1306000, 133.7100000, 'active', '2026-01-31 19:07:09', '2026-01-31 19:07:09'),
(600, 'CFH', NULL, 'Clifton Hills Airport', NULL, 'AU', 'South Australia', -27.0183000, 138.8920000, 'active', '2026-01-31 19:07:10', '2026-01-31 19:07:10'),
(601, 'CPD', 'YCBP', 'Coober Pedy Airport', NULL, 'AU', 'South Australia', -29.0400000, 134.7210000, 'active', '2026-01-31 19:07:10', '2026-01-31 19:07:10'),
(602, 'CRJ', NULL, 'Coorabie Airport', NULL, 'AU', 'South Australia', -31.8944000, 132.2960000, 'active', '2026-01-31 19:07:11', '2026-01-31 19:07:11'),
(603, 'CVC', 'YCEE', 'Cleve Airport', NULL, 'AU', 'South Australia', -33.7097000, 136.5050000, 'active', '2026-01-31 19:07:11', '2026-01-31 19:07:11'),
(604, 'CWR', 'YCWI', 'Cowarie Airport', NULL, 'AU', 'South Australia', -27.7117000, 138.3280000, 'active', '2026-01-31 19:07:11', '2026-01-31 19:07:11'),
(605, 'DLK', 'YDLK', 'Dulkaninna Airport', NULL, 'AU', 'South Australia', -29.0133000, 138.4810000, 'active', '2026-01-31 19:07:12', '2026-01-31 19:07:12'),
(606, 'ERB', 'YERN', 'Pukatja Airport (Ernabella Airport)', NULL, 'AU', 'South Australia', -26.2633000, 132.1820000, 'active', '2026-01-31 19:07:12', '2026-01-31 19:07:12'),
(607, 'ETD', 'YEDA', 'Etadunna Airport', NULL, 'AU', 'South Australia', -28.7408000, 138.5890000, 'active', '2026-01-31 19:07:12', '2026-01-31 19:07:12'),
(608, 'GSN', 'YMGN', 'Mount Gunson Airport', NULL, 'AU', 'South Australia', -31.4597000, 137.1740000, 'active', '2026-01-31 19:07:13', '2026-01-31 19:07:13'),
(609, 'HWK', 'YHAW', 'Wilpena Pound Airport', NULL, 'AU', 'South Australia', -31.8559000, 138.4680000, 'active', '2026-01-31 19:07:13', '2026-01-31 19:07:13'),
(610, 'IDK', 'YIDK', 'Indulkana Airport', NULL, 'AU', 'South Australia', -26.9667000, 133.3250000, 'active', '2026-01-31 19:07:13', '2026-01-31 19:07:13'),
(611, 'INM', 'YINN', 'Innamincka Airport', NULL, 'AU', 'South Australia', -27.7000000, 140.7330000, 'active', '2026-01-31 19:07:14', '2026-01-31 19:07:14'),
(612, 'KBY', 'YKBY', 'Streaky Bay Airport', NULL, 'AU', 'South Australia', -32.8358000, 134.2930000, 'active', '2026-01-31 19:07:14', '2026-01-31 19:07:14'),
(613, 'KGC', 'YKSC', 'Kingscote Airport', NULL, 'AU', 'South Australia', -35.7139000, 137.5210000, 'active', '2026-01-31 19:07:14', '2026-01-31 19:07:14'),
(614, 'KYI', 'YYTA', 'Yalata Airport', NULL, 'AU', 'South Australia', -31.4706000, 131.8250000, 'active', '2026-01-31 19:07:15', '2026-01-31 19:07:15'),
(615, 'LCN', 'YBLC', 'Balcanoona Airport', NULL, 'AU', 'South Australia', -30.5350000, 139.3370000, 'active', '2026-01-31 19:07:15', '2026-01-31 19:07:15'),
(616, 'LGH', 'YLEC', 'Leigh Creek Airport', NULL, 'AU', 'South Australia', -30.5983000, 138.4260000, 'active', '2026-01-31 19:07:15', '2026-01-31 19:07:15'),
(617, 'LOC', 'YLOK', 'Lock Airport', NULL, 'AU', 'South Australia', -33.5442000, 135.6930000, 'active', '2026-01-31 19:07:16', '2026-01-31 19:07:16'),
(618, 'MGB', 'YMTG', 'Mount Gambier Airport', NULL, 'AU', 'South Australia', -37.7456000, 140.7850000, 'active', '2026-01-31 19:07:16', '2026-01-31 19:07:16'),
(619, 'MIN', 'YMPA', 'Minnipa Airport', NULL, 'AU', 'South Australia', -32.8433000, 135.1450000, 'active', '2026-01-31 19:07:16', '2026-01-31 19:07:16'),
(620, 'MLR', 'YMCT', 'Millicent Airport', NULL, 'AU', 'South Australia', -37.5836000, 140.3660000, 'active', '2026-01-31 19:07:17', '2026-01-31 19:07:17'),
(621, 'MNE', 'YMUG', 'Mungeranie Airport', NULL, 'AU', 'South Australia', -28.0092000, 138.6570000, 'active', '2026-01-31 19:07:17', '2026-01-31 19:07:17'),
(622, 'MOO', 'YOOM', 'Moomba Airport', NULL, 'AU', 'South Australia', -28.0994000, 140.1970000, 'active', '2026-01-31 19:07:17', '2026-01-31 19:07:17'),
(623, 'MRP', 'YALA', 'Marla Airport', NULL, 'AU', 'South Australia', -27.3333000, 133.6270000, 'active', '2026-01-31 19:07:18', '2026-01-31 19:07:18'),
(624, 'MVK', 'YMUK', 'Mulka Airport', NULL, 'AU', 'South Australia', -28.3478000, 138.6500000, 'active', '2026-01-31 19:07:18', '2026-01-31 19:07:18'),
(625, 'MWT', 'YMWT', 'Moolawatana Airport', NULL, 'AU', 'South Australia', -29.9069000, 139.7650000, 'active', '2026-01-31 19:07:18', '2026-01-31 19:07:18'),
(626, 'NAC', 'YNRC', 'Naracoorte Airport', NULL, 'AU', 'South Australia', -36.9853000, 140.7250000, 'active', '2026-01-31 19:07:19', '2026-01-31 19:07:19'),
(627, 'NUR', 'YNUB', 'Nullabor Motel Airport', NULL, 'AU', 'South Australia', -31.4417000, 130.9020000, 'active', '2026-01-31 19:07:19', '2026-01-31 19:07:19'),
(628, 'ODD', 'YOOD', 'Oodnadatta Airport', NULL, 'AU', 'South Australia', -27.5617000, 135.4470000, 'active', '2026-01-31 19:07:19', '2026-01-31 19:07:19'),
(629, 'ODL', 'YCOD', 'Cordillo Downs Airport', NULL, 'AU', 'South Australia', -26.7453000, 140.6380000, 'active', '2026-01-31 19:07:20', '2026-01-31 19:07:20'),
(630, 'OLP', 'YOLD', 'Olympic Dam Airport', NULL, 'AU', 'South Australia', -30.4850000, 136.8770000, 'active', '2026-01-31 19:07:20', '2026-01-31 19:07:20'),
(631, 'ORR', 'YYOR', 'Yorketown Airport', NULL, 'AU', 'South Australia', -35.0000000, 137.6170000, 'active', '2026-01-31 19:07:20', '2026-01-31 19:07:20'),
(632, 'PDE', 'YPDI', 'Pandie Pandie Airport', NULL, 'AU', 'South Australia', -26.1167000, 139.4000000, 'active', '2026-01-31 19:07:21', '2026-01-31 19:07:21'),
(633, 'PDN', NULL, 'Parndana Airport', NULL, 'AU', 'South Australia', -35.8070000, 137.2640000, 'active', '2026-01-31 19:07:21', '2026-01-31 19:07:21'),
(634, 'PEA', 'YPSH', 'Penneshaw Airport', NULL, 'AU', 'South Australia', -35.7558000, 137.9630000, 'active', '2026-01-31 19:07:21', '2026-01-31 19:07:21'),
(635, 'PEY', NULL, 'Penong Airport', NULL, 'AU', 'South Australia', -31.9167000, 133.0000000, 'active', '2026-01-31 19:07:22', '2026-01-31 19:07:22'),
(636, 'PLO', 'YPLC', 'Port Lincoln Airport', NULL, 'AU', 'South Australia', -34.6053000, 135.8800000, 'active', '2026-01-31 19:07:22', '2026-01-31 19:07:22'),
(637, 'PPI', 'YPIR', 'Port Pirie Airport', NULL, 'AU', 'South Australia', -33.2389000, 137.9950000, 'active', '2026-01-31 19:07:22', '2026-01-31 19:07:22'),
(638, 'PUG', 'YPAG', 'Port Augusta Airport', NULL, 'AU', 'South Australia', -32.5069000, 137.7170000, 'active', '2026-01-31 19:07:23', '2026-01-31 19:07:23'),
(639, 'PXH', 'YPMH', 'Prominent Hill Airport', NULL, 'AU', 'South Australia', -29.7160000, 135.5240000, 'active', '2026-01-31 19:07:23', '2026-01-31 19:07:23'),
(640, 'RCN', NULL, 'American River Airport', NULL, 'AU', 'South Australia', -35.7574000, 137.7760000, 'active', '2026-01-31 19:07:24', '2026-01-31 19:07:24'),
(641, 'RMK', 'YREN', 'Renmark Airport', NULL, 'AU', 'South Australia', -34.1964000, 140.6740000, 'active', '2026-01-31 19:07:24', '2026-01-31 19:07:24'),
(642, 'RRE', 'YMRE', 'Marree Airport', NULL, 'AU', 'South Australia', -29.6633000, 138.0650000, 'active', '2026-01-31 19:07:24', '2026-01-31 19:07:24'),
(643, 'RTY', 'YMYT', 'Merty Merty Airport', NULL, 'AU', 'South Australia', -28.5833000, 140.3170000, 'active', '2026-01-31 19:07:25', '2026-01-31 19:07:25'),
(644, 'TAQ', NULL, 'Tarcoola Airport', NULL, 'AU', 'South Australia', -30.7033000, 134.5840000, 'active', '2026-01-31 19:07:25', '2026-01-31 19:07:25'),
(645, 'UMR', 'YPWR', 'RAAF Woomera Airfield', NULL, 'AU', 'South Australia', -31.1442000, 136.8170000, 'active', '2026-01-31 19:07:25', '2026-01-31 19:07:25'),
(646, 'WUD', 'YWUD', 'Wudinna Airport', NULL, 'AU', 'South Australia', -33.0433000, 135.4470000, 'active', '2026-01-31 19:07:26', '2026-01-31 19:07:26'),
(647, 'WYA', 'YWHA', 'Whyalla Airport', NULL, 'AU', 'South Australia', -33.0589000, 137.5140000, 'active', '2026-01-31 19:07:26', '2026-01-31 19:07:26'),
(648, 'XML', 'YMIN', 'Minlaton Airport', NULL, 'AU', 'South Australia', -34.7500000, 137.5330000, 'active', '2026-01-31 19:07:26', '2026-01-31 19:07:26'),
(649, 'BWT', 'YWYY', 'Burnie Airport', NULL, 'AU', 'Tasmania', -40.9989000, 145.7310000, 'active', '2026-01-31 19:07:27', '2026-01-31 19:07:27'),
(650, 'CBI', NULL, 'Cape Barren Island Airport', NULL, 'AU', 'Tasmania', -40.3917000, 148.0170000, 'active', '2026-01-31 19:07:27', '2026-01-31 19:07:27'),
(651, 'DPO', 'YDPO', 'Devonport Airport', NULL, 'AU', 'Tasmania', -41.1697000, 146.4300000, 'active', '2026-01-31 19:07:27', '2026-01-31 19:07:27');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(652, 'FLS', 'YFLI', 'Flinders Island Airport', NULL, 'AU', 'Tasmania', -40.0917000, 147.9930000, 'active', '2026-01-31 19:07:28', '2026-01-31 19:07:28'),
(653, 'GEE', 'YGTO', 'George Town Aerodrome', NULL, 'AU', 'Tasmania', -41.0800000, 146.8400000, 'active', '2026-01-31 19:07:28', '2026-01-31 19:07:28'),
(654, 'HBA', 'YMHB', 'Hobart International Airport', NULL, 'AU', 'Tasmania', -42.8361000, 147.5100000, 'active', '2026-01-31 19:07:28', '2026-01-31 19:07:28'),
(655, 'HLS', 'YSTH', 'St Helens Airport', NULL, 'AU', 'Tasmania', -41.3367000, 148.2820000, 'active', '2026-01-31 19:07:29', '2026-01-31 19:07:29'),
(656, 'KNS', 'YKII', 'King Island Airport', NULL, 'AU', 'Tasmania', -39.8775000, 143.8780000, 'active', '2026-01-31 19:07:29', '2026-01-31 19:07:29'),
(657, 'LST', 'YMLT', 'Launceston Airport', NULL, 'AU', 'Tasmania', -41.5453000, 147.2140000, 'active', '2026-01-31 19:07:29', '2026-01-31 19:07:29'),
(658, 'LTB', NULL, 'Latrobe Airport', NULL, 'AU', 'Tasmania', -41.2352000, 146.3960000, 'active', '2026-01-31 19:07:30', '2026-01-31 19:07:30'),
(659, 'SIO', 'YSMI', 'Smithton Airport', NULL, 'AU', 'Tasmania', -40.8350000, 145.0840000, 'active', '2026-01-31 19:07:30', '2026-01-31 19:07:30'),
(660, 'SRN', 'YSRN', 'Strahan Airport', NULL, 'AU', 'Tasmania', -42.1550000, 145.2920000, 'active', '2026-01-31 19:07:30', '2026-01-31 19:07:30'),
(661, 'UEE', 'YQNS', 'Queenstown Airport', NULL, 'AU', 'Tasmania', -42.0750000, 145.5320000, 'active', '2026-01-31 19:07:31', '2026-01-31 19:07:31'),
(662, 'ARY', 'YARA', 'Ararat Airport', NULL, 'AU', 'Victoria', -37.3094000, 142.9890000, 'active', '2026-01-31 19:07:31', '2026-01-31 19:07:31'),
(663, 'AVV', 'YMAV', 'Avalon Airport', NULL, 'AU', 'Victoria', -38.0394000, 144.4690000, 'active', '2026-01-31 19:07:32', '2026-01-31 19:07:32'),
(664, 'BLN', 'YBLA', 'Benalla Airport', NULL, 'AU', 'Victoria', -36.5519000, 146.0070000, 'active', '2026-01-31 19:07:32', '2026-01-31 19:07:32'),
(665, 'BRJ', NULL, 'Bright Airport', NULL, 'AU', 'Victoria', -36.7330000, 146.9670000, 'active', '2026-01-31 19:07:32', '2026-01-31 19:07:32'),
(666, 'BSJ', 'YBNS', 'Bairnsdale Airport', NULL, 'AU', 'Victoria', -37.8875000, 147.5680000, 'active', '2026-01-31 19:07:33', '2026-01-31 19:07:33'),
(667, 'BXG', 'YBDG', 'Bendigo Airport', NULL, 'AU', 'Victoria', -36.7394000, 144.3300000, 'active', '2026-01-31 19:07:33', '2026-01-31 19:07:33'),
(668, 'CYG', 'YCRG', 'Corryong Airport', NULL, 'AU', 'Victoria', -36.1828000, 147.8880000, 'active', '2026-01-31 19:07:33', '2026-01-31 19:07:33'),
(669, 'ECH', 'YECH', 'Echuca Airport', NULL, 'AU', 'Victoria', -36.1572000, 144.7620000, 'active', '2026-01-31 19:07:34', '2026-01-31 19:07:34'),
(670, 'GEX', 'YGLG', 'Geelong Airport', NULL, 'AU', 'Victoria', -38.2250000, 144.3330000, 'active', '2026-01-31 19:07:34', '2026-01-31 19:07:34'),
(671, 'HLT', 'YHML', 'Hamilton Airport', NULL, 'AU', 'Victoria', -37.6489000, 142.0650000, 'active', '2026-01-31 19:07:34', '2026-01-31 19:07:34'),
(672, 'HSM', 'YHSM', 'Horsham Airport', NULL, 'AU', 'Victoria', -36.6697000, 142.1730000, 'active', '2026-01-31 19:07:35', '2026-01-31 19:07:35'),
(673, 'HTU', 'YHPN', 'Hopetoun Airport', NULL, 'AU', 'Victoria', -35.7153000, 142.3600000, 'active', '2026-01-31 19:07:35', '2026-01-31 19:07:35'),
(674, 'KRA', 'YKER', 'Kerang Airport', NULL, 'AU', 'Victoria', -35.7514000, 143.9390000, 'active', '2026-01-31 19:07:35', '2026-01-31 19:07:35'),
(675, 'MBF', 'YPOK', 'Porepunkah Airfield', NULL, 'AU', 'Victoria', -36.7187000, 146.8900000, 'active', '2026-01-31 19:07:36', '2026-01-31 19:07:36'),
(676, 'MBW', 'YMMB', 'Moorabbin Airport', NULL, 'AU', 'Victoria', -37.9758000, 145.1020000, 'active', '2026-01-31 19:07:36', '2026-01-31 19:07:36'),
(677, 'MEB', 'YMEN', 'Essendon Airport', NULL, 'AU', 'Victoria', -37.7281000, 144.9020000, 'active', '2026-01-31 19:07:36', '2026-01-31 19:07:36'),
(678, 'MEL', 'YMML', 'Melbourne Airport', NULL, 'AU', 'Victoria', -37.6733000, 144.8430000, 'active', '2026-01-31 19:07:37', '2026-01-31 19:07:37'),
(679, 'MHU', 'YHOT', 'Mount Hotham Airport', NULL, 'AU', 'Victoria', -37.0475000, 147.3340000, 'active', '2026-01-31 19:07:37', '2026-01-31 19:07:37'),
(680, 'MQL', 'YMIA', 'Mildura Airport', NULL, 'AU', 'Victoria', -34.2292000, 142.0860000, 'active', '2026-01-31 19:07:37', '2026-01-31 19:07:37'),
(681, 'OYN', 'YOUY', 'Ouyen Airport', NULL, 'AU', 'Victoria', -35.0890000, 142.3540000, 'active', '2026-01-31 19:07:38', '2026-01-31 19:07:38'),
(682, 'PTJ', 'YPOD', 'Portland Airport', NULL, 'AU', 'Victoria', -38.3181000, 141.4710000, 'active', '2026-01-31 19:07:38', '2026-01-31 19:07:38'),
(683, 'RBC', 'YROI', 'Robinvale Airport', NULL, 'AU', 'Victoria', -34.6500000, 142.7830000, 'active', '2026-01-31 19:07:38', '2026-01-31 19:07:38'),
(684, 'RBS', 'YORB', 'Orbost Airport', NULL, 'AU', 'Victoria', -37.7900000, 148.6100000, 'active', '2026-01-31 19:07:39', '2026-01-31 19:07:39'),
(685, 'SHT', 'YSHT', 'Shepparton Airport', NULL, 'AU', 'Victoria', -36.4289000, 145.3930000, 'active', '2026-01-31 19:07:39', '2026-01-31 19:07:39'),
(686, 'SWC', 'YSWL', 'Stawell Airport', NULL, 'AU', 'Victoria', -37.0717000, 142.7410000, 'active', '2026-01-31 19:07:40', '2026-01-31 19:07:40'),
(687, 'SWH', 'YSWH', 'Swan Hill Airport', NULL, 'AU', 'Victoria', -35.3758000, 143.5330000, 'active', '2026-01-31 19:07:40', '2026-01-31 19:07:40'),
(688, 'SXE', 'YWSL', 'West Sale Airport', NULL, 'AU', 'Victoria', -38.0908000, 146.9650000, 'active', '2026-01-31 19:07:40', '2026-01-31 19:07:40'),
(689, 'TGN', 'YLTV', 'Latrobe Regional Airport', NULL, 'AU', 'Victoria', -38.2072000, 146.4700000, 'active', '2026-01-31 19:07:41', '2026-01-31 19:07:41'),
(690, 'WGT', 'YWGT', 'Wangaratta Airport', NULL, 'AU', 'Victoria', -36.4158000, 146.3070000, 'active', '2026-01-31 19:07:41', '2026-01-31 19:07:41'),
(691, 'WHL', NULL, 'Welshpool Airport', NULL, 'AU', 'Victoria', -38.6824000, 146.4450000, 'active', '2026-01-31 19:07:41', '2026-01-31 19:07:41'),
(692, 'WKB', 'YWKB', 'Warracknabeal Airport', NULL, 'AU', 'Victoria', -36.3211000, 142.4190000, 'active', '2026-01-31 19:07:42', '2026-01-31 19:07:42'),
(693, 'WMB', 'YWBL', 'Warrnambool Airport', NULL, 'AU', 'Victoria', -38.2953000, 142.4470000, 'active', '2026-01-31 19:07:42', '2026-01-31 19:07:42'),
(694, 'XCO', 'YOLA', 'Colac Airport', NULL, 'AU', 'Victoria', -38.2867000, 143.6800000, 'active', '2026-01-31 19:07:42', '2026-01-31 19:07:42'),
(695, 'XMC', 'YMCO', 'Mallacoota Airport', NULL, 'AU', 'Victoria', -37.5983000, 149.7200000, 'active', '2026-01-31 19:07:43', '2026-01-31 19:07:43'),
(696, 'ALH', 'YABA', 'Albany Airport', NULL, 'AU', 'Western Australia', -34.9433000, 117.8090000, 'active', '2026-01-31 19:07:43', '2026-01-31 19:07:43'),
(697, 'BDW', 'YBDF', 'Bedford Downs Airport', NULL, 'AU', 'Western Australia', -17.2867000, 127.4630000, 'active', '2026-01-31 19:07:44', '2026-01-31 19:07:44'),
(698, 'BEE', NULL, 'Beagle Bay Airport', NULL, 'AU', 'Western Australia', -17.0165000, 122.6460000, 'active', '2026-01-31 19:07:44', '2026-01-31 19:07:44'),
(699, 'BIW', NULL, 'Billiluna Airport', NULL, 'AU', 'Western Australia', -19.5667000, 127.6670000, 'active', '2026-01-31 19:07:44', '2026-01-31 19:07:44'),
(700, 'BME', 'YBRM', 'Broome International Airport', NULL, 'AU', 'Western Australia', -17.9447000, 122.2320000, 'active', '2026-01-31 19:07:45', '2026-01-31 19:07:45'),
(701, 'BQB', 'YBLN', 'Busselton Regional Airport', NULL, 'AU', 'Western Australia', -33.6884000, 115.4020000, 'active', '2026-01-31 19:07:45', '2026-01-31 19:07:45'),
(702, 'BQW', 'YBGO', 'Balgo Hill Airport', NULL, 'AU', 'Western Australia', -20.1483000, 127.9730000, 'active', '2026-01-31 19:07:45', '2026-01-31 19:07:45'),
(703, 'BUY', 'YBUN', 'Bunbury Airport', NULL, 'AU', 'Western Australia', -33.3783000, 115.6770000, 'active', '2026-01-31 19:07:46', '2026-01-31 19:07:46'),
(704, 'BVZ', 'YBYS', 'Beverley Springs Airport', NULL, 'AU', 'Western Australia', -16.7333000, 125.4330000, 'active', '2026-01-31 19:07:46', '2026-01-31 19:07:46'),
(705, 'BWB', 'YBWX', 'Barrow Island Airport', NULL, 'AU', 'Western Australia', -20.8644000, 115.4060000, 'active', '2026-01-31 19:07:46', '2026-01-31 19:07:46'),
(706, 'BXF', 'YBEB', 'Bellburn Airstrip', NULL, 'AU', 'Western Australia', -17.5450000, 128.3050000, 'active', '2026-01-31 19:07:47', '2026-01-31 19:07:47'),
(707, 'BYP', 'YBRY', 'Barimunya Airport', NULL, 'AU', 'Western Australia', -22.6739000, 119.1660000, 'active', '2026-01-31 19:07:47', '2026-01-31 19:07:47'),
(708, 'CBC', NULL, 'Cherrabun Airport', NULL, 'AU', 'Western Australia', -18.9178000, 125.5380000, 'active', '2026-01-31 19:07:48', '2026-01-31 19:07:48'),
(709, 'CGV', 'YCAG', 'Caiguna Airport', NULL, 'AU', 'Western Australia', -32.2650000, 125.4930000, 'active', '2026-01-31 19:07:48', '2026-01-31 19:07:48'),
(710, 'CIE', 'YCOI', 'Collie Airport', NULL, 'AU', 'Western Australia', -33.3667000, 116.2170000, 'active', '2026-01-31 19:07:48', '2026-01-31 19:07:48'),
(711, 'CJF', 'YCWA', 'Coondewanna Airport', NULL, 'AU', 'Western Australia', -22.9667000, 118.8130000, 'active', '2026-01-31 19:07:49', '2026-01-31 19:07:49'),
(712, 'CKW', 'YCHK', 'Christmas Creek Mine Airport', NULL, 'AU', 'Western Australia', -22.3543000, 119.6430000, 'active', '2026-01-31 19:07:49', '2026-01-31 19:07:49'),
(713, 'COY', 'YCWY', 'Coolawanyah Station Airport', NULL, 'AU', 'Western Australia', -21.7946000, 117.7550000, 'active', '2026-01-31 19:07:49', '2026-01-31 19:07:49'),
(714, 'CRY', NULL, 'Carlton Hill Airport', NULL, 'AU', 'Western Australia', -15.5019000, 128.5340000, 'active', '2026-01-31 19:07:50', '2026-01-31 19:07:50'),
(715, 'CUY', 'YCUE', 'Cue Airport', NULL, 'AU', 'Western Australia', -27.4467000, 117.9180000, 'active', '2026-01-31 19:07:50', '2026-01-31 19:07:50'),
(716, 'CVQ', 'YCAR', 'Carnarvon Airport', NULL, 'AU', 'Western Australia', -24.8802000, 113.6720000, 'active', '2026-01-31 19:07:50', '2026-01-31 19:07:50'),
(717, 'CXQ', NULL, 'Christmas Creek Stn Airport', NULL, 'AU', 'Western Australia', -22.3567000, 119.6520000, 'active', '2026-01-31 19:07:51', '2026-01-31 19:07:51'),
(718, 'DCN', 'YCIN', 'RAAF Base Curtin', NULL, 'AU', 'Western Australia', -17.5814000, 123.8280000, 'active', '2026-01-31 19:07:51', '2026-01-31 19:07:51'),
(719, 'DGD', 'YDGA', 'Dalgaranga Airport', NULL, 'AU', 'Western Australia', -27.8303000, 117.3160000, 'active', '2026-01-31 19:07:51', '2026-01-31 19:07:51'),
(720, 'DNG', NULL, 'Doongan Airport', NULL, 'AU', 'Western Australia', -15.3864000, 126.3020000, 'active', '2026-01-31 19:07:52', '2026-01-31 19:07:52'),
(721, 'DNM', NULL, 'Denham Airport', NULL, 'AU', 'Western Australia', -25.8882000, 113.5770000, 'active', '2026-01-31 19:07:52', '2026-01-31 19:07:52'),
(722, 'DOX', 'YDRA', 'Dongara Airport', NULL, 'AU', 'Western Australia', -29.2981000, 114.9270000, 'active', '2026-01-31 19:07:53', '2026-01-31 19:07:53'),
(723, 'DRB', 'YDBY', 'Derby Airport', NULL, 'AU', 'Western Australia', -17.3700000, 123.6610000, 'active', '2026-01-31 19:07:53', '2026-01-31 19:07:53'),
(724, 'DRY', 'YDRD', 'Drysdale River Airport', NULL, 'AU', 'Western Australia', -15.7136000, 126.3810000, 'active', '2026-01-31 19:07:53', '2026-01-31 19:07:53'),
(725, 'ENB', 'YEEB', 'Eneabba Airport', NULL, 'AU', 'Western Australia', -29.8325000, 115.2460000, 'active', '2026-01-31 19:07:54', '2026-01-31 19:07:54'),
(726, 'EPR', 'YESP', 'Esperance Airport', NULL, 'AU', 'Western Australia', -33.6844000, 121.8230000, 'active', '2026-01-31 19:07:54', '2026-01-31 19:07:54'),
(727, 'EUC', 'YECL', 'Eucla Airport', NULL, 'AU', 'Western Australia', -31.7000000, 128.8830000, 'active', '2026-01-31 19:07:54', '2026-01-31 19:07:54'),
(728, 'EXM', 'YEXM', 'Exmouth Airport', NULL, 'AU', 'Western Australia', -22.0333000, 114.1000000, 'active', '2026-01-31 19:07:55', '2026-01-31 19:07:55'),
(729, 'FIZ', 'YFTZ', 'Fitzroy Crossing Airport', NULL, 'AU', 'Western Australia', -18.1819000, 125.5590000, 'active', '2026-01-31 19:07:55', '2026-01-31 19:07:55'),
(730, 'FOS', 'YFRT', 'Forrest Airport', NULL, 'AU', 'Western Australia', -30.8381000, 128.1150000, 'active', '2026-01-31 19:07:55', '2026-01-31 19:07:55'),
(731, 'FSL', NULL, 'Fossil Downs Airport', NULL, 'AU', 'Western Australia', -18.1321000, 125.7870000, 'active', '2026-01-31 19:07:56', '2026-01-31 19:07:56'),
(732, 'FVL', 'YFLO', 'Flora Valley Airport', NULL, 'AU', 'Western Australia', -18.2833000, 128.4170000, 'active', '2026-01-31 19:07:56', '2026-01-31 19:07:56'),
(733, 'FVR', 'YFRV', 'Forrest River Airport', NULL, 'AU', 'Western Australia', -15.1647000, 127.8400000, 'active', '2026-01-31 19:07:56', '2026-01-31 19:07:56'),
(734, 'GBV', 'YGIB', 'Gibb River Airport', NULL, 'AU', 'Western Australia', -16.4233000, 126.4450000, 'active', '2026-01-31 19:07:57', '2026-01-31 19:07:57'),
(735, 'GBW', 'YGIA', 'Ginbata Airport', NULL, 'AU', 'Western Australia', -22.5812000, 120.0360000, 'active', '2026-01-31 19:07:57', '2026-01-31 19:07:57'),
(736, 'GDD', 'YGDN', 'Gordon Downs Airport', NULL, 'AU', 'Western Australia', -18.6781000, 128.5920000, 'active', '2026-01-31 19:07:57', '2026-01-31 19:07:57'),
(737, 'GET', 'YGEL', 'Geraldton Airport', NULL, 'AU', 'Western Australia', -28.7961000, 114.7070000, 'active', '2026-01-31 19:07:58', '2026-01-31 19:07:58'),
(738, 'GLY', NULL, 'Goldsworthy Airport', NULL, 'AU', 'Western Australia', -20.3330000, 119.5000000, 'active', '2026-01-31 19:07:58', '2026-01-31 19:07:58'),
(739, 'GSC', 'YGSC', 'Gascoyne Junction Airport', NULL, 'AU', 'Western Australia', -25.0546000, 115.2030000, 'active', '2026-01-31 19:07:58', '2026-01-31 19:07:58'),
(740, 'GYL', 'YARG', 'Argyle Airport', NULL, 'AU', 'Western Australia', -16.6369000, 128.4510000, 'active', '2026-01-31 19:07:59', '2026-01-31 19:07:59'),
(741, 'HCQ', 'YHLC', 'Halls Creek Airport', NULL, 'AU', 'Western Australia', -18.2339000, 127.6700000, 'active', '2026-01-31 19:07:59', '2026-01-31 19:07:59'),
(742, 'HLL', 'YHIL', 'Hillside Airport', NULL, 'AU', 'Western Australia', -21.7244000, 119.3920000, 'active', '2026-01-31 19:07:59', '2026-01-31 19:07:59'),
(743, 'JAD', 'YPJT', 'Jandakot Airport', NULL, 'AU', 'Western Australia', -32.0975000, 115.8810000, 'active', '2026-01-31 19:08:00', '2026-01-31 19:08:00'),
(744, 'JUR', 'YJNB', 'Jurien Bay Airport', NULL, 'AU', 'Western Australia', -30.3016000, 115.0560000, 'active', '2026-01-31 19:08:00', '2026-01-31 19:08:00'),
(745, 'KAX', 'YKBR', 'Kalbarri Airport', NULL, 'AU', 'Western Australia', -27.6928000, 114.2590000, 'active', '2026-01-31 19:08:00', '2026-01-31 19:08:00'),
(746, 'KBD', NULL, 'Kimberley Downs Airport', NULL, 'AU', 'Western Australia', -17.3978000, 124.3550000, 'active', '2026-01-31 19:08:01', '2026-01-31 19:08:01'),
(747, 'KDB', 'YKBL', 'Kambalda Airport', NULL, 'AU', 'Western Australia', -31.1907000, 121.5980000, 'active', '2026-01-31 19:08:01', '2026-01-31 19:08:01'),
(748, 'KFE', 'YFDF', 'Fortescue Dave Forrest Airport', NULL, 'AU', 'Western Australia', -22.2908000, 119.4370000, 'active', '2026-01-31 19:08:01', '2026-01-31 19:08:01'),
(749, 'KGI', 'YPKG', 'Kalgoorlie-Boulder Airport', NULL, 'AU', 'Western Australia', -30.7894000, 121.4620000, 'active', '2026-01-31 19:08:02', '2026-01-31 19:08:02'),
(750, 'KNI', 'YKNG', 'Katanning Airport', NULL, 'AU', 'Western Australia', -33.7167000, 117.6330000, 'active', '2026-01-31 19:08:02', '2026-01-31 19:08:02'),
(751, 'KNX', 'YPKU', 'East Kimberley Regional Airport', NULL, 'AU', 'Western Australia', -15.7781000, 128.7080000, 'active', '2026-01-31 19:08:02', '2026-01-31 19:08:02'),
(752, 'KQR', 'YKAR', 'Karara Airport', NULL, 'AU', 'Western Australia', -29.2167000, 116.6870000, 'active', '2026-01-31 19:08:03', '2026-01-31 19:08:03'),
(753, 'KTA', 'YPKA', 'Karratha Airport', NULL, 'AU', 'Western Australia', -20.7122000, 116.7730000, 'active', '2026-01-31 19:08:03', '2026-01-31 19:08:03'),
(754, 'KYF', 'YYLR', 'Yeelirrie Airport', NULL, 'AU', 'Western Australia', -27.2771000, 120.0960000, 'active', '2026-01-31 19:08:03', '2026-01-31 19:08:03'),
(755, 'LDW', NULL, 'Lansdowne Airport', NULL, 'AU', 'Western Australia', -17.6128000, 126.7430000, 'active', '2026-01-31 19:08:04', '2026-01-31 19:08:04'),
(756, 'LEA', 'YPLM', 'RAAF Learmonth (Learmonth Airport)', NULL, 'AU', 'Western Australia', -22.2356000, 114.0890000, 'active', '2026-01-31 19:08:04', '2026-01-31 19:08:04'),
(757, 'LER', 'YLST', 'Leinster Airport', NULL, 'AU', 'Western Australia', -27.8433000, 120.7030000, 'active', '2026-01-31 19:08:05', '2026-01-31 19:08:05'),
(758, 'LGE', NULL, 'Lake Gregory Airport', NULL, 'AU', 'Western Australia', -20.1089000, 127.6190000, 'active', '2026-01-31 19:08:05', '2026-01-31 19:08:05'),
(759, 'LLL', NULL, 'Lissadell Airport', NULL, 'AU', 'Western Australia', -16.6610000, 128.5940000, 'active', '2026-01-31 19:08:05', '2026-01-31 19:08:05'),
(760, 'LNO', 'YLEO', 'Leonora Airport', NULL, 'AU', 'Western Australia', -28.8781000, 121.3150000, 'active', '2026-01-31 19:08:06', '2026-01-31 19:08:06'),
(761, 'LVO', 'YLTN', 'Laverton Airport', NULL, 'AU', 'Western Australia', -28.6136000, 122.4240000, 'active', '2026-01-31 19:08:06', '2026-01-31 19:08:06'),
(762, 'MBB', 'YMBL', 'Marble Bar Airport', NULL, 'AU', 'Western Australia', -21.1633000, 119.8330000, 'active', '2026-01-31 19:08:06', '2026-01-31 19:08:06'),
(763, 'MBN', NULL, 'Mount Barnett Airport', NULL, 'AU', 'Western Australia', -16.6573000, 125.9610000, 'active', '2026-01-31 19:08:07', '2026-01-31 19:08:07'),
(764, 'MGV', 'YMGR', 'Margaret River Station Airport', NULL, 'AU', 'Western Australia', -18.6217000, 126.8830000, 'active', '2026-01-31 19:08:07', '2026-01-31 19:08:07'),
(765, 'MHO', 'YMHO', 'Mount House Airport', NULL, 'AU', 'Western Australia', -17.0550000, 125.7100000, 'active', '2026-01-31 19:08:07', '2026-01-31 19:08:07'),
(766, 'MIH', 'YMIP', 'Mitchell Plateau Airport', NULL, 'AU', 'Western Australia', -14.7914000, 125.8240000, 'active', '2026-01-31 19:08:08', '2026-01-31 19:08:08'),
(767, 'MJK', 'YSHK', 'Shark Bay Airport', NULL, 'AU', 'Western Australia', -25.8939000, 113.5770000, 'active', '2026-01-31 19:08:08', '2026-01-31 19:08:08'),
(768, 'MJP', 'YMJM', 'Manjimup Airport', NULL, 'AU', 'Western Australia', -34.2653000, 116.1400000, 'active', '2026-01-31 19:08:08', '2026-01-31 19:08:08'),
(769, 'MKR', 'YMEK', 'Meekatharra Airport', NULL, 'AU', 'Western Australia', -26.6117000, 118.5480000, 'active', '2026-01-31 19:08:09', '2026-01-31 19:08:09'),
(770, 'MMG', 'YMOG', 'Mount Magnet Airport', NULL, 'AU', 'Western Australia', -28.1161000, 117.8420000, 'active', '2026-01-31 19:08:09', '2026-01-31 19:08:09'),
(771, 'MQA', 'YMDI', 'Mandora Station Airport', NULL, 'AU', 'Western Australia', -19.7383000, 120.8380000, 'active', '2026-01-31 19:08:09', '2026-01-31 19:08:09'),
(772, 'MQZ', 'YMGT', 'Margaret River Airport', NULL, 'AU', 'Western Australia', -33.9306000, 115.1000000, 'active', '2026-01-31 19:08:10', '2026-01-31 19:08:10'),
(773, 'MUQ', 'YMUC', 'Muccan Station Airport', NULL, 'AU', 'Western Australia', -20.6589000, 120.0670000, 'active', '2026-01-31 19:08:10', '2026-01-31 19:08:10'),
(774, 'MWB', 'YMRW', 'Morawa Airport', NULL, 'AU', 'Western Australia', -29.2017000, 116.0220000, 'active', '2026-01-31 19:08:10', '2026-01-31 19:08:10'),
(775, 'MXU', 'YMWA', 'Mullewa Airport', NULL, 'AU', 'Western Australia', -28.4750000, 115.5170000, 'active', '2026-01-31 19:08:11', '2026-01-31 19:08:11'),
(776, 'MYO', 'YMYR', 'Myroodah Airport', NULL, 'AU', 'Western Australia', -18.1247000, 124.2720000, 'active', '2026-01-31 19:08:11', '2026-01-31 19:08:11'),
(777, 'NDS', 'YSAN', 'Sandstone Airport', NULL, 'AU', 'Western Australia', -27.9800000, 119.2970000, 'active', '2026-01-31 19:08:11', '2026-01-31 19:08:11'),
(778, 'NIF', 'YCNF', 'Nifty Airport', NULL, 'AU', 'Western Australia', -21.6717000, 121.5870000, 'active', '2026-01-31 19:08:12', '2026-01-31 19:08:12'),
(779, 'NKB', NULL, 'Noonkanbah Airport', NULL, 'AU', 'Western Australia', -18.4947000, 124.8520000, 'active', '2026-01-31 19:08:12', '2026-01-31 19:08:12'),
(780, 'NLL', 'YNUL', 'Nullagine Airport', NULL, 'AU', 'Western Australia', -21.9133000, 120.1980000, 'active', '2026-01-31 19:08:12', '2026-01-31 19:08:12'),
(781, 'NLS', NULL, 'Nicholson Airport', NULL, 'AU', 'Western Australia', -18.0500000, 128.9000000, 'active', '2026-01-31 19:08:13', '2026-01-31 19:08:13'),
(782, 'NRG', 'YNRG', 'Narrogin Airport', NULL, 'AU', 'Western Australia', -32.9300000, 117.0800000, 'active', '2026-01-31 19:08:13', '2026-01-31 19:08:13'),
(783, 'NSM', 'YNSM', 'Norseman Airport', NULL, 'AU', 'Western Australia', -32.2100000, 121.7550000, 'active', '2026-01-31 19:08:13', '2026-01-31 19:08:13'),
(784, 'OCM', 'YBGD', 'Boolgeeda Airport', NULL, 'AU', 'Western Australia', -22.5400000, 117.2750000, 'active', '2026-01-31 19:08:14', '2026-01-31 19:08:14'),
(785, 'ODR', 'YORV', 'Ord River Airport', NULL, 'AU', 'Western Australia', -17.3408000, 128.9120000, 'active', '2026-01-31 19:08:14', '2026-01-31 19:08:14'),
(786, 'ONS', 'YOLW', 'Onslow Airport', NULL, 'AU', 'Western Australia', -21.6683000, 115.1130000, 'active', '2026-01-31 19:08:14', '2026-01-31 19:08:14'),
(787, 'PBO', 'YPBO', 'Paraburdoo Airport', NULL, 'AU', 'Western Australia', -23.1711000, 117.7450000, 'active', '2026-01-31 19:08:15', '2026-01-31 19:08:15'),
(788, 'PER', 'YPPH', 'Perth Airport', NULL, 'AU', 'Western Australia', -31.9403000, 115.9670000, 'active', '2026-01-31 19:08:15', '2026-01-31 19:08:15'),
(789, 'PHE', 'YPPD', 'Port Hedland International Airport', NULL, 'AU', 'Western Australia', -20.3778000, 118.6260000, 'active', '2026-01-31 19:08:15', '2026-01-31 19:08:15'),
(790, 'PRD', 'YPDO', 'Pardoo Airport', NULL, 'AU', 'Western Australia', -20.1175000, 119.5900000, 'active', '2026-01-31 19:08:16', '2026-01-31 19:08:16'),
(791, 'RBU', 'YROE', 'Roebourne Airport', NULL, 'AU', 'Western Australia', -20.7617000, 117.1570000, 'active', '2026-01-31 19:08:16', '2026-01-31 19:08:16'),
(792, 'RHL', 'YRYH', 'Roy Hill Station Airport', NULL, 'AU', 'Western Australia', -22.6258000, 119.9590000, 'active', '2026-01-31 19:08:17', '2026-01-31 19:08:17'),
(793, 'RTS', 'YRTI', 'Rottnest Island Airport', NULL, 'AU', 'Western Australia', -32.0067000, 115.5400000, 'active', '2026-01-31 19:08:17', '2026-01-31 19:08:17'),
(794, 'RVT', 'YNRV', 'Ravensthorpe Airport', NULL, 'AU', 'Western Australia', -33.7972000, 120.2080000, 'active', '2026-01-31 19:08:17', '2026-01-31 19:08:17'),
(795, 'SGP', 'YSHG', 'Shay Gap Airport', NULL, 'AU', 'Western Australia', -20.4247000, 120.1410000, 'active', '2026-01-31 19:08:18', '2026-01-31 19:08:18'),
(796, 'SLJ', 'YSOL', 'Solomon Airport', NULL, 'AU', 'Western Australia', -22.2554000, 117.7630000, 'active', '2026-01-31 19:08:18', '2026-01-31 19:08:18'),
(797, 'SQC', 'YSCR', 'Southern Cross Airport', NULL, 'AU', 'Western Australia', -31.2400000, 119.3600000, 'active', '2026-01-31 19:08:18', '2026-01-31 19:08:18'),
(798, 'SSK', NULL, 'Sturt Creek Airport', NULL, 'AU', 'Western Australia', -19.1664000, 128.1740000, 'active', '2026-01-31 19:08:19', '2026-01-31 19:08:19'),
(799, 'SWB', NULL, 'Shaw River Airport', NULL, 'AU', 'Western Australia', -21.5103000, 119.3620000, 'active', '2026-01-31 19:08:19', '2026-01-31 19:08:19'),
(800, 'TBL', 'YTAB', 'Tableland Homestead Airport', NULL, 'AU', 'Western Australia', -17.2833000, 126.9000000, 'active', '2026-01-31 19:08:19', '2026-01-31 19:08:19'),
(801, 'TDN', 'YTHD', 'Theda Station Airport', NULL, 'AU', 'Western Australia', -14.7881000, 126.4960000, 'active', '2026-01-31 19:08:20', '2026-01-31 19:08:20'),
(802, 'TEF', 'YTEF', 'Telfer Airport', NULL, 'AU', 'Western Australia', -21.7150000, 122.2290000, 'active', '2026-01-31 19:08:20', '2026-01-31 19:08:20'),
(803, 'TKY', 'YTKY', 'Turkey Creek Airport', NULL, 'AU', 'Western Australia', -17.0408000, 128.2060000, 'active', '2026-01-31 19:08:20', '2026-01-31 19:08:20'),
(804, 'TPR', 'YTMP', 'Tom Price Airport', NULL, 'AU', 'Western Australia', -22.7460000, 117.8690000, 'active', '2026-01-31 19:08:21', '2026-01-31 19:08:21'),
(805, 'TTX', 'YTST', 'Truscott-Mungalalu Airport', NULL, 'AU', 'Western Australia', -14.0897000, 126.3810000, 'active', '2026-01-31 19:08:21', '2026-01-31 19:08:21'),
(806, 'UBU', 'YKAL', 'Kalumburu Airport', NULL, 'AU', 'Western Australia', -14.2883000, 126.6320000, 'active', '2026-01-31 19:08:21', '2026-01-31 19:08:21'),
(807, 'USL', 'YUSL', 'Useless Loop Airport', NULL, 'AU', 'Western Australia', -26.1667000, 113.4000000, 'active', '2026-01-31 19:08:22', '2026-01-31 19:08:22'),
(808, 'WIT', 'YWIT', 'Wittenoom Airport', NULL, 'AU', 'Western Australia', -22.2183000, 118.3480000, 'active', '2026-01-31 19:08:22', '2026-01-31 19:08:22'),
(809, 'WLA', 'YWAL', 'Wallal Airport', NULL, 'AU', 'Western Australia', -19.7736000, 120.6490000, 'active', '2026-01-31 19:08:22', '2026-01-31 19:08:22'),
(810, 'WLP', 'YANG', 'West Angelas Airport', NULL, 'AU', 'Western Australia', -23.1356000, 118.7070000, 'active', '2026-01-31 19:08:23', '2026-01-31 19:08:23'),
(811, 'WME', 'YMNE', 'Mount Keith Airport', NULL, 'AU', 'Western Australia', -27.2864000, 120.5550000, 'active', '2026-01-31 19:08:23', '2026-01-31 19:08:23'),
(812, 'WND', NULL, 'Windarra Airport', NULL, 'AU', 'Western Australia', -28.4750000, 122.2420000, 'active', '2026-01-31 19:08:23', '2026-01-31 19:08:23'),
(813, 'WRN', 'YWDG', 'Windarling Airport', NULL, 'AU', 'Western Australia', -30.0317000, 119.3900000, 'active', '2026-01-31 19:08:24', '2026-01-31 19:08:24'),
(814, 'WRW', 'YWWG', 'Warrawagine Airport', NULL, 'AU', 'Western Australia', -20.8442000, 120.7020000, 'active', '2026-01-31 19:08:24', '2026-01-31 19:08:24'),
(815, 'WUI', 'YMMI', 'Murrin Murrin Airport', NULL, 'AU', 'Western Australia', -28.7053000, 121.8910000, 'active', '2026-01-31 19:08:24', '2026-01-31 19:08:24'),
(816, 'WUN', 'YWLU', 'Wiluna Airport', NULL, 'AU', 'Western Australia', -26.6292000, 120.2210000, 'active', '2026-01-31 19:08:25', '2026-01-31 19:08:25'),
(817, 'WWI', 'YWWI', 'Woodie Woodie Airport', NULL, 'AU', 'Western Australia', -21.6628000, 121.2340000, 'active', '2026-01-31 19:08:25', '2026-01-31 19:08:25'),
(818, 'WYN', 'YWYM', 'Wyndham Airport', NULL, 'AU', 'Western Australia', -15.5114000, 128.1530000, 'active', '2026-01-31 19:08:25', '2026-01-31 19:08:25'),
(819, 'YLG', 'YYAL', 'Yalgoo Airport', NULL, 'AU', 'Western Australia', -28.3553000, 116.6840000, 'active', '2026-01-31 19:08:26', '2026-01-31 19:08:26'),
(820, 'YNN', NULL, 'Yandicoogina Airport', NULL, 'AU', 'Western Australia', 59.4875000, -97.7803000, 'active', '2026-01-31 19:08:26', '2026-01-31 19:08:26'),
(821, 'ZNE', 'YNWN', 'Newman Airport', NULL, 'AU', 'Western Australia', -23.4178000, 119.8030000, 'active', '2026-01-31 19:08:26', '2026-01-31 19:08:26'),
(822, 'ZVG', NULL, 'Springvale Airport (Western Australia)', NULL, 'AU', 'Western Australia', -17.7869000, 127.6700000, 'active', '2026-01-31 19:08:27', '2026-01-31 19:08:27'),
(823, 'AUA', 'TNCA', 'Queen Beatrix International Airport', NULL, 'AW', 'Aruba', 12.5014000, -70.0152000, 'active', '2026-01-31 19:08:27', '2026-01-31 19:08:27'),
(824, 'GYD', 'UBBB', 'Heydar Aliyev International Airport', NULL, 'AZ', 'Baki', 40.4675000, 50.0467000, 'active', '2026-01-31 19:08:27', '2026-01-31 19:08:27'),
(825, 'FZL', 'UBBF', 'Fuzuli Airport', NULL, 'AZ', 'Fuzuli', 39.5955000, 47.1973000, 'active', '2026-01-31 19:08:28', '2026-01-31 19:08:28'),
(826, 'GNJ', 'UBBG', 'Ganja International Airport (formerly KVD)', NULL, 'AZ', 'Ganca', 40.7377000, 46.3176000, 'active', '2026-01-31 19:08:28', '2026-01-31 19:08:28'),
(827, 'LLK', 'UBBL', 'Lankaran International Airport', NULL, 'AZ', 'Lankaran', 38.7464000, 48.8180000, 'active', '2026-01-31 19:08:28', '2026-01-31 19:08:28'),
(828, 'NAJ', 'UBBN', 'Nakhchivan International Airport', NULL, 'AZ', 'Naxcivan', 39.1888000, 45.4584000, 'active', '2026-01-31 19:08:29', '2026-01-31 19:08:29'),
(829, 'GBB', 'UBBQ', 'Qabala International Airport', NULL, 'AZ', 'Qabala', 40.8267000, 47.7125000, 'active', '2026-01-31 19:08:29', '2026-01-31 19:08:29'),
(830, 'YLV', 'UBEE', 'Yevlakh Airport', NULL, 'AZ', 'Yevlax', 40.6319000, 47.1419000, 'active', '2026-01-31 19:08:29', '2026-01-31 19:08:29'),
(831, 'ZTU', 'UBBY', 'Zaqatala International Airport', NULL, 'AZ', 'Zaqatala', 41.5622000, 46.6672000, 'active', '2026-01-31 19:08:30', '2026-01-31 19:08:30'),
(832, 'OMO', 'LQMO', 'Mostar Airport', NULL, 'BA', 'Federacija Bosne i Hercegovine', 43.2829000, 17.8459000, 'active', '2026-01-31 19:08:30', '2026-01-31 19:08:30'),
(833, 'SJJ', 'LQSA', 'Sarajevo International Airport', NULL, 'BA', 'Federacija Bosne i Hercegovine', 43.8246000, 18.3315000, 'active', '2026-01-31 19:08:30', '2026-01-31 19:08:30'),
(834, 'TZL', 'LQTZ', 'Tuzla International Airport', NULL, 'BA', 'Federacija Bosne i Hercegovine', 44.4587000, 18.7248000, 'active', '2026-01-31 19:08:31', '2026-01-31 19:08:31'),
(835, 'BNX', 'LQBK', 'Banja Luka International Airport', NULL, 'BA', 'Republika Srpska', 44.9414000, 17.2975000, 'active', '2026-01-31 19:08:31', '2026-01-31 19:08:31'),
(836, 'BGI', 'TBPB', 'Grantley Adams International Airport', NULL, 'BB', 'Christ Church', 13.0746000, -59.4925000, 'active', '2026-01-31 19:08:32', '2026-01-31 19:08:32'),
(837, 'BZL', 'VGBR', 'Barisal Airport', NULL, 'BD', 'Barisal', 22.8010000, 90.3012000, 'active', '2026-01-31 19:08:32', '2026-01-31 19:08:32'),
(838, 'CGP', 'VGEG', 'Shah Amanat International Airport', NULL, 'BD', 'Chittagong', 22.2496000, 91.8133000, 'active', '2026-01-31 19:08:32', '2026-01-31 19:08:32'),
(839, 'CLA', 'VGCM', 'Comilla Airport', NULL, 'BD', 'Chittagong', 23.4372000, 91.1897000, 'active', '2026-01-31 19:08:33', '2026-01-31 19:08:33'),
(840, 'CXB', 'VGCB', 'Cox\'s Bazar Airport', NULL, 'BD', 'Chittagong', 21.4522000, 91.9639000, 'active', '2026-01-31 19:08:33', '2026-01-31 19:08:33'),
(841, 'DAC', 'VGHS', 'Hazrat Shahjalal International Airport', NULL, 'BD', 'Dhaka', 23.8433000, 90.3978000, 'active', '2026-01-31 19:08:34', '2026-01-31 19:08:34'),
(842, 'JSR', 'VGJR', 'Jessore Airport', NULL, 'BD', 'Khulna', 23.1838000, 89.1608000, 'active', '2026-01-31 19:08:34', '2026-01-31 19:08:34'),
(843, 'IRD', 'VGIS', 'Ishwardi Airport', NULL, 'BD', 'Rajshahi', 24.1525000, 89.0494000, 'active', '2026-01-31 19:08:34', '2026-01-31 19:08:34'),
(844, 'RJH', 'VGRJ', 'Shah Makhdum Airport', NULL, 'BD', 'Rajshahi', 24.4372000, 88.6165000, 'active', '2026-01-31 19:08:35', '2026-01-31 19:08:35'),
(845, 'SPD', 'VGSD', 'Saidpur Airport', NULL, 'BD', 'Rangpur', 25.7592000, 88.9089000, 'active', '2026-01-31 19:08:35', '2026-01-31 19:08:35'),
(846, 'TKR', 'VGSG', 'Thakurgaon Airport', NULL, 'BD', 'Rangpur', 26.0164000, 88.4036000, 'active', '2026-01-31 19:08:35', '2026-01-31 19:08:35'),
(847, 'ZHM', 'VGSH', 'Shamshernagar Airport', NULL, 'BD', 'Sylhet', 24.4170000, 91.8830000, 'active', '2026-01-31 19:08:36', '2026-01-31 19:08:36'),
(848, 'ZYL', 'VGSY', 'Osmani International Airport', NULL, 'BD', 'Sylhet', 24.9632000, 91.8668000, 'active', '2026-01-31 19:08:36', '2026-01-31 19:08:36'),
(849, 'ANR', 'EBAW', 'Antwerp International Airport', NULL, 'BE', 'Antwerpen', 51.1894000, 4.4602800, 'active', '2026-01-31 19:08:36', '2026-01-31 19:08:36'),
(850, 'OBL', 'EBZR', 'Oostmalle Airfield', NULL, 'BE', 'Antwerpen', 51.2647000, 4.7533300, 'active', '2026-01-31 19:08:37', '2026-01-31 19:08:37'),
(851, 'BRU', 'EBBR', 'Brussels Airport (Zaventem Airport)', NULL, 'BE', 'Brussels Hoofdstedelijk Gewest', 50.9014000, 4.4844400, 'active', '2026-01-31 19:08:37', '2026-01-31 19:08:37'),
(852, 'CRL', 'EBCI', 'Brussels South Charleroi Airport', NULL, 'BE', 'Hainaut', 50.4592000, 4.4538200, 'active', '2026-01-31 19:08:37', '2026-01-31 19:08:37'),
(853, 'LGG', 'EBLG', 'Liege Airport', NULL, 'BE', 'Liege', 50.6374000, 5.4432200, 'active', '2026-01-31 19:08:38', '2026-01-31 19:08:38'),
(854, 'KJK', 'EBKT', 'Kortrijk-Wevelgem International Airport', NULL, 'BE', 'West-Vlaanderen', 50.8172000, 3.2047200, 'active', '2026-01-31 19:08:38', '2026-01-31 19:08:38'),
(855, 'OST', 'EBOS', 'Ostend-Bruges International Airport', NULL, 'BE', 'West-Vlaanderen', 51.1989000, 2.8622200, 'active', '2026-01-31 19:08:38', '2026-01-31 19:08:38'),
(856, 'XDE', 'DFOU', 'Diebougou Airport', NULL, 'BF', 'Bougouriba', 10.9500000, -3.2500000, 'active', '2026-01-31 19:08:39', '2026-01-31 19:08:39'),
(857, 'TEG', 'DFET', 'Tenkodogo Airport', NULL, 'BF', 'Boulgou', 11.8000000, -0.3670000, 'active', '2026-01-31 19:08:39', '2026-01-31 19:08:39'),
(858, 'XZA', 'DFEZ', 'Zabre Airport', NULL, 'BF', 'Boulgou', 11.1670000, -0.6170000, 'active', '2026-01-31 19:08:39', '2026-01-31 19:08:39'),
(859, 'BNR', 'DFOB', 'Banfora Airport', NULL, 'BF', 'Comoe', 10.6830000, -4.7170000, 'active', '2026-01-31 19:08:40', '2026-01-31 19:08:40'),
(860, 'XBG', 'DFEB', 'Bogande Airport', NULL, 'BF', 'Gnagna', 12.9830000, -0.1670000, 'active', '2026-01-31 19:08:40', '2026-01-31 19:08:40'),
(861, 'FNG', 'DFEF', 'Fada N\'gourma Airport', NULL, 'BF', 'Gourma', 12.0330000, 0.3500000, 'active', '2026-01-31 19:08:40', '2026-01-31 19:08:40'),
(862, 'BOY', 'DFOO', 'Bobo Dioulasso Airport', NULL, 'BF', 'Houet', 11.1601000, -4.3309700, 'active', '2026-01-31 19:08:41', '2026-01-31 19:08:41'),
(863, 'OUA', 'DFFD', 'Ouagadougou Airport', NULL, 'BF', 'Kadiogo', 12.3532000, -1.5124200, 'active', '2026-01-31 19:08:41', '2026-01-31 19:08:41'),
(864, 'XPA', 'DFEP', 'Pama Airport', NULL, 'BF', 'Kompienga', 11.2500000, 0.7000000, 'active', '2026-01-31 19:08:41', '2026-01-31 19:08:41'),
(865, 'XNU', 'DFON', 'Nouna Airport', NULL, 'BF', 'Kossi', 12.7500000, -3.8670000, 'active', '2026-01-31 19:08:42', '2026-01-31 19:08:42'),
(866, 'DGU', 'DFOD', 'Dedougou Airport', NULL, 'BF', 'Mouhoun', 12.4590000, -3.4900000, 'active', '2026-01-31 19:08:42', '2026-01-31 19:08:42'),
(867, 'PUP', 'DFCP', 'Po Airport', NULL, 'BF', 'Nahouri', 11.1500000, -1.1500000, 'active', '2026-01-31 19:08:42', '2026-01-31 19:08:42'),
(868, 'XBO', 'DFEA', 'Boulsa Airport', NULL, 'BF', 'Namentenga', 12.6500000, -0.5670000, 'active', '2026-01-31 19:08:43', '2026-01-31 19:08:43'),
(869, 'TMQ', 'DFEM', 'Tambao Airport', NULL, 'BF', 'Oudalan', 14.8000000, 0.0500000, 'active', '2026-01-31 19:08:43', '2026-01-31 19:08:43'),
(870, 'XGG', 'DFEG', 'Gorom Gorom Airport', NULL, 'BF', 'Oudalan', 14.4500000, -0.2330000, 'active', '2026-01-31 19:08:43', '2026-01-31 19:08:43'),
(871, 'XGA', 'DFOG', 'Gaoua Airport (Amilcar Cabral Airport)', NULL, 'BF', 'Poni', 10.3841000, -3.1634500, 'active', '2026-01-31 19:08:44', '2026-01-31 19:08:44'),
(872, 'XKY', 'DFCA', 'Kaya Airport', NULL, 'BF', 'Sanmatenga', 13.0670000, -1.1000000, 'active', '2026-01-31 19:08:44', '2026-01-31 19:08:44'),
(873, 'DOR', 'DFEE', 'Dori Airport', NULL, 'BF', 'Seno', 14.0330000, -0.0330000, 'active', '2026-01-31 19:08:44', '2026-01-31 19:08:44'),
(874, 'XLU', 'DFCL', 'Leo Airport', NULL, 'BF', 'Sissili', 11.1000000, -2.1000000, 'active', '2026-01-31 19:08:45', '2026-01-31 19:08:45'),
(875, 'XAR', 'DFOY', 'Aribinda Airport', NULL, 'BF', 'Soum', 14.2170000, -0.8830000, 'active', '2026-01-31 19:08:45', '2026-01-31 19:08:45'),
(876, 'XDJ', 'DFCJ', 'Djibo Airport', NULL, 'BF', 'Soum', 14.1000000, -1.6330000, 'active', '2026-01-31 19:08:45', '2026-01-31 19:08:45'),
(877, 'TUQ', 'DFOT', 'Tougan Airport', NULL, 'BF', 'Sourou', 13.0670000, -3.0670000, 'active', '2026-01-31 19:08:46', '2026-01-31 19:08:46'),
(878, 'ARL', 'DFER', 'Arly Airport', NULL, 'BF', 'Tapoa', 11.5970000, 1.4830000, 'active', '2026-01-31 19:08:46', '2026-01-31 19:08:46'),
(879, 'DIP', 'DFED', 'Diapaga Airport', NULL, 'BF', 'Tapoa', 12.0603000, 1.7846300, 'active', '2026-01-31 19:08:46', '2026-01-31 19:08:46'),
(880, 'XKA', 'DFEL', 'Kantchari Airport', NULL, 'BF', 'Tapoa', 12.4670000, 1.5000000, 'active', '2026-01-31 19:08:47', '2026-01-31 19:08:47'),
(881, 'XSE', 'DFES', 'Sebba Airport', NULL, 'BF', 'Yagha', 13.4500000, 0.5170000, 'active', '2026-01-31 19:08:47', '2026-01-31 19:08:47'),
(882, 'OUG', 'DFCC', 'Ouahigouya Airport', NULL, 'BF', 'Yatenga', 13.5670000, -2.4170000, 'active', '2026-01-31 19:08:48', '2026-01-31 19:08:48'),
(883, 'BOJ', 'LBBG', 'Burgas Airport', NULL, 'BG', 'Burgas', 42.5696000, 27.5152000, 'active', '2026-01-31 19:08:48', '2026-01-31 19:08:48'),
(884, 'HKV', 'LBHS', 'Haskovo Malevo Airport', NULL, 'BG', 'Haskovo', 41.8718000, 25.6048000, 'active', '2026-01-31 19:08:48', '2026-01-31 19:08:48'),
(885, 'PDV', 'LBPD', 'Plovdiv Airport', NULL, 'BG', 'Plovdiv', 42.0678000, 24.8508000, 'active', '2026-01-31 19:08:49', '2026-01-31 19:08:49'),
(886, 'ROU', 'LBRS', 'Ruse Airport', NULL, 'BG', 'Ruse', 43.6948000, 26.0567000, 'active', '2026-01-31 19:08:49', '2026-01-31 19:08:49'),
(887, 'SLS', 'LBSS', 'Silistra Airfield', NULL, 'BG', 'Silistra', 44.0552000, 27.1788000, 'active', '2026-01-31 19:08:49', '2026-01-31 19:08:49'),
(888, 'SOF', 'LBSF', 'Sofia Airport', NULL, 'BG', 'Sofia', 42.6967000, 23.4114000, 'active', '2026-01-31 19:08:50', '2026-01-31 19:08:50'),
(889, 'SZR', 'LBSZ', 'Stara Zagora Airport', NULL, 'BG', 'Stara Zagora', 42.3767000, 25.6550000, 'active', '2026-01-31 19:08:50', '2026-01-31 19:08:50'),
(890, 'TGV', 'LBTG', 'Targovishte Airport (Buhovtsi Airfield)', NULL, 'BG', 'Targovishte', 43.3066000, 26.7009000, 'active', '2026-01-31 19:08:50', '2026-01-31 19:08:50'),
(891, 'VAR', 'LBWN', 'Varna Airport', NULL, 'BG', 'Varna', 43.2321000, 27.8251000, 'active', '2026-01-31 19:08:51', '2026-01-31 19:08:51'),
(892, 'GOZ', 'LBGO', 'Gorna Oryahovitsa Airport', NULL, 'BG', 'Veliko Tarnovo', 43.1514000, 25.7129000, 'active', '2026-01-31 19:08:51', '2026-01-31 19:08:51'),
(893, 'JAM', NULL, 'Bezmer Air Base', NULL, 'BG', 'Yambol', 42.4549000, 26.3522000, 'active', '2026-01-31 19:08:51', '2026-01-31 19:08:51'),
(894, 'BAH', 'OBBI', 'Bahrain International Airport', NULL, 'BH', 'Al Muharraq', 26.2708000, 50.6336000, 'active', '2026-01-31 19:08:52', '2026-01-31 19:08:52'),
(895, 'BJM', 'HBBA', 'Bujumbura International Airport', NULL, 'BI', 'Bujumbura Mairie', -3.3240200, 29.3185000, 'active', '2026-01-31 19:08:52', '2026-01-31 19:08:52'),
(896, 'GID', 'HBBE', 'Gitega Airport', NULL, 'BI', 'Gitega', -3.4172100, 29.9113000, 'active', '2026-01-31 19:08:52', '2026-01-31 19:08:52'),
(897, 'KRE', 'HBBO', 'Kirundo Airport', NULL, 'BI', 'Kirundo', -2.5447700, 30.0946000, 'active', '2026-01-31 19:08:53', '2026-01-31 19:08:53'),
(898, 'KDC', 'DBBK', 'Kandi Airport', NULL, 'BJ', 'Alibori', 11.1448000, 2.9403800, 'active', '2026-01-31 19:08:53', '2026-01-31 19:08:53'),
(899, 'NAE', 'DBBN', 'Boundetingou Airport', NULL, 'BJ', 'Atacora', 10.3770000, 1.3605100, 'active', '2026-01-31 19:08:53', '2026-01-31 19:08:53'),
(900, 'PKO', 'DBBP', 'Parakou Airport', NULL, 'BJ', 'Borgou', 9.3576900, 2.6096800, 'active', '2026-01-31 19:08:54', '2026-01-31 19:08:54'),
(901, 'SVF', 'DBBS', 'Save Airport', NULL, 'BJ', 'Collines', 8.0181700, 2.4645800, 'active', '2026-01-31 19:08:54', '2026-01-31 19:08:54'),
(902, 'DJA', 'DBBD', 'Djougou Airport', NULL, 'BJ', 'Donga', 9.6920800, 1.6377800, 'active', '2026-01-31 19:08:54', '2026-01-31 19:08:54'),
(903, 'COO', 'DBBB', 'Cadjehoun Airport', NULL, 'BJ', 'Littoral', 6.3572300, 2.3843500, 'active', '2026-01-31 19:08:55', '2026-01-31 19:08:55'),
(904, 'SBH', 'TFFJ', 'Gustaf III Airport', NULL, 'BL', 'Saint Barthelemy', 17.9044000, -62.8436000, 'active', '2026-01-31 19:08:55', '2026-01-31 19:08:55'),
(905, 'BDA', 'TXKF', 'L.F. Wade International Airport', NULL, 'BM', 'Hamilton', 32.3640000, -64.6787000, 'active', '2026-01-31 19:08:55', '2026-01-31 19:08:55'),
(906, 'BWN', 'WBSB', 'Brunei International Airport', NULL, 'BN', 'Brunei-Muara', 4.9442000, 114.9280000, 'active', '2026-01-31 19:08:56', '2026-01-31 19:08:56'),
(907, 'MHW', 'SLAG', 'Monteagudo Airport', NULL, 'BO', 'Chuquisaca', -19.8270000, -63.9610000, 'active', '2026-01-31 19:08:56', '2026-01-31 19:08:56'),
(908, 'SRE', 'SLSU', 'Juana Azurduy de Padilla International Airport', NULL, 'BO', 'Chuquisaca', -19.2468000, -65.1496000, 'active', '2026-01-31 19:08:56', '2026-01-31 19:08:56'),
(909, 'SRJ', 'SLSB', 'Capitan German Quiroga Guardia Airport', NULL, 'BO', 'Chuquisaca', -14.8592000, -66.7375000, 'active', '2026-01-31 19:08:57', '2026-01-31 19:08:57'),
(910, 'CBB', 'SLCB', 'Jorge Wilstermann International Airport', NULL, 'BO', 'Cochabamba', -17.4211000, -66.1771000, 'active', '2026-01-31 19:08:57', '2026-01-31 19:08:57'),
(911, 'CCA', 'SLHI', 'Chimore Airport', NULL, 'BO', 'Cochabamba', -16.9889000, -65.1417000, 'active', '2026-01-31 19:08:57', '2026-01-31 19:08:57'),
(912, 'BVK', 'SLHJ', 'Huacaraje Airport', NULL, 'BO', 'El Beni', -13.5500000, -63.7479000, 'active', '2026-01-31 19:08:58', '2026-01-31 19:08:58'),
(913, 'BVL', 'SLBU', 'Baures Airport', NULL, 'BO', 'El Beni', -13.5833000, -63.5833000, 'active', '2026-01-31 19:08:58', '2026-01-31 19:08:58'),
(914, 'GYA', 'SLGY', 'Guayaramerin Airport', NULL, 'BO', 'El Beni', -10.8206000, -65.3456000, 'active', '2026-01-31 19:08:58', '2026-01-31 19:08:58'),
(915, 'MGD', 'SLMG', 'Magdalena Airport', NULL, 'BO', 'El Beni', -13.2607000, -64.0608000, 'active', '2026-01-31 19:08:59', '2026-01-31 19:08:59'),
(916, 'RBQ', 'SLRQ', 'Rurrenabaque Airport', NULL, 'BO', 'El Beni', -14.4279000, -67.4968000, 'active', '2026-01-31 19:08:59', '2026-01-31 19:08:59'),
(917, 'REY', 'SLRY', 'Reyes Airport', NULL, 'BO', 'El Beni', -14.3044000, -67.3534000, 'active', '2026-01-31 19:08:59', '2026-01-31 19:08:59'),
(918, 'RIB', 'SLRI', 'Riberalta Airport', NULL, 'BO', 'El Beni', -11.0000000, -66.0000000, 'active', '2026-01-31 19:09:00', '2026-01-31 19:09:00'),
(919, 'SBL', 'SLSA', 'Santa Ana del Yacuma Airport', NULL, 'BO', 'El Beni', -13.7622000, -65.4352000, 'active', '2026-01-31 19:09:00', '2026-01-31 19:09:00'),
(920, 'SJB', 'SLJO', 'San Joaquin Airport', NULL, 'BO', 'El Beni', -13.0528000, -64.6617000, 'active', '2026-01-31 19:09:01', '2026-01-31 19:09:01'),
(921, 'SNM', 'SLSM', 'San Ignacio de Moxos Airport', NULL, 'BO', 'El Beni', -14.9658000, -65.6338000, 'active', '2026-01-31 19:09:01', '2026-01-31 19:09:01'),
(922, 'SRB', 'SLSR', 'Santa Rosa Airport (Bolivia)', NULL, 'BO', 'El Beni', -14.0662000, -66.7868000, 'active', '2026-01-31 19:09:01', '2026-01-31 19:09:01'),
(923, 'SRD', 'SLRA', 'San Ramon Airport', NULL, 'BO', 'El Beni', -13.2639000, -64.6039000, 'active', '2026-01-31 19:09:02', '2026-01-31 19:09:02'),
(924, 'TDD', 'SLTR', 'Teniente Jorge Henrich Arauz Airport', NULL, 'BO', 'El Beni', -14.8187000, -64.9180000, 'active', '2026-01-31 19:09:02', '2026-01-31 19:09:02'),
(925, 'APB', 'SLAP', 'Apolo Airport', NULL, 'BO', 'La Paz', -14.7356000, -68.4119000, 'active', '2026-01-31 19:09:02', '2026-01-31 19:09:02'),
(926, 'LPB', 'SLLP', 'El Alto International Airport', NULL, 'BO', 'La Paz', -16.5133000, -68.1923000, 'active', '2026-01-31 19:09:03', '2026-01-31 19:09:03'),
(927, 'ORU', 'SLOR', 'Juan Mendoza Airport', NULL, 'BO', 'Oruro', -17.9626000, -67.0762000, 'active', '2026-01-31 19:09:03', '2026-01-31 19:09:03'),
(928, 'CIJ', 'SLCO', 'Captain Anibal Arab Airport', NULL, 'BO', 'Pando', -11.0404000, -68.7830000, 'active', '2026-01-31 19:09:03', '2026-01-31 19:09:03'),
(929, 'PUR', 'SLPR', 'Puerto Rico Airport', NULL, 'BO', 'Pando', -11.1077000, -67.5512000, 'active', '2026-01-31 19:09:04', '2026-01-31 19:09:04'),
(930, 'POI', 'SLPO', 'Captain Nicolas Rojas Airport', NULL, 'BO', 'Potosi', -19.5433000, -65.7237000, 'active', '2026-01-31 19:09:04', '2026-01-31 19:09:04'),
(931, 'UYU', 'SLUY', 'Uyuni Airport (Joya Andina Airport)', NULL, 'BO', 'Potosi', -20.4463000, -66.8484000, 'active', '2026-01-31 19:09:04', '2026-01-31 19:09:04'),
(932, 'ASC', 'SLAS', 'Ascencion de Guarayos Airport', NULL, 'BO', 'Santa Cruz', -15.9303000, -63.1567000, 'active', '2026-01-31 19:09:05', '2026-01-31 19:09:05'),
(933, 'CAM', 'SLCA', 'Camiri Airport', NULL, 'BO', 'Santa Cruz', -20.0064000, -63.5278000, 'active', '2026-01-31 19:09:05', '2026-01-31 19:09:05'),
(934, 'CEP', 'SLCP', 'Concepcion Airport', NULL, 'BO', 'Santa Cruz', -16.1383000, -62.0286000, 'active', '2026-01-31 19:09:05', '2026-01-31 19:09:05'),
(935, 'MQK', 'SLTI', 'San Matias Airport', NULL, 'BO', 'Santa Cruz', -16.3392000, -58.4019000, 'active', '2026-01-31 19:09:06', '2026-01-31 19:09:06'),
(936, 'PSZ', 'SLPS', 'Puerto Suarez International Airport', NULL, 'BO', 'Santa Cruz', -18.9753000, -57.8206000, 'active', '2026-01-31 19:09:06', '2026-01-31 19:09:06'),
(937, 'RBO', 'SLRB', 'Robore Airport', NULL, 'BO', 'Santa Cruz', -18.3292000, -59.7650000, 'active', '2026-01-31 19:09:06', '2026-01-31 19:09:06'),
(938, 'SJS', 'SLJE', 'San Jose de Chiquitos Airport', NULL, 'BO', 'Santa Cruz', -17.8308000, -60.7431000, 'active', '2026-01-31 19:09:07', '2026-01-31 19:09:07'),
(939, 'SJV', 'SLJV', 'San Javier Airport (Bolivia)', NULL, 'BO', 'Santa Cruz', -16.2708000, -62.4703000, 'active', '2026-01-31 19:09:07', '2026-01-31 19:09:07'),
(940, 'SNG', 'SLSI', 'Capitan Av. Juan Cochamanidis Air', NULL, 'BO', 'Santa Cruz', -16.3836000, -60.9628000, 'active', '2026-01-31 19:09:07', '2026-01-31 19:09:07'),
(941, 'SRZ', 'SLET', 'El Trompillo Airport', NULL, 'BO', 'Santa Cruz', -17.8116000, -63.1715000, 'active', '2026-01-31 19:09:08', '2026-01-31 19:09:08'),
(942, 'VAH', 'SLVG', 'Cap. Av. Vidal Villagomez Toledo Airport', NULL, 'BO', 'Santa Cruz', -18.4825000, -64.0994000, 'active', '2026-01-31 19:09:08', '2026-01-31 19:09:08'),
(943, 'VVI', 'SLVR', 'Viru Viru International Airport', NULL, 'BO', 'Santa Cruz', -17.6448000, -63.1354000, 'active', '2026-01-31 19:09:09', '2026-01-31 19:09:09'),
(944, 'BJO', 'SLBJ', 'Bermejo Airport', NULL, 'BO', 'Tarija', -22.7733000, -64.3129000, 'active', '2026-01-31 19:09:09', '2026-01-31 19:09:09'),
(945, 'BYC', 'SLYA', 'Yacuiba Airport', NULL, 'BO', 'Tarija', -21.9609000, -63.6517000, 'active', '2026-01-31 19:09:09', '2026-01-31 19:09:09'),
(946, 'TJA', 'SLTJ', 'Capitan Oriel Lea Plaza Airport', NULL, 'BO', 'Tarija', -21.5557000, -64.7013000, 'active', '2026-01-31 19:09:10', '2026-01-31 19:09:10'),
(947, 'VLM', 'SLVM', 'Lieutenant Colonel Rafael Pabon Airport', NULL, 'BO', 'Tarija', -21.2552000, -63.4056000, 'active', '2026-01-31 19:09:10', '2026-01-31 19:09:10'),
(948, 'BON', 'TNCB', 'Flamingo International Airport', NULL, 'BQ', 'Bonaire', 12.1310000, -68.2685000, 'active', '2026-01-31 19:09:10', '2026-01-31 19:09:10'),
(949, 'SAB', 'TNCS', 'Juancho E. Yrausquin Airport', NULL, 'BQ', 'Saba', 17.6450000, -63.2200000, 'active', '2026-01-31 19:09:11', '2026-01-31 19:09:11'),
(950, 'EUX', 'TNCE', 'F. D. Roosevelt Airport', NULL, 'BQ', 'Sint Eustatius', 17.4965000, -62.9794000, 'active', '2026-01-31 19:09:11', '2026-01-31 19:09:11'),
(951, 'CZS', 'SBCZ', 'Cruzeiro do Sul International Airport', NULL, 'BR', 'Acre', -7.5999100, -72.7695000, 'active', '2026-01-31 19:09:11', '2026-01-31 19:09:11'),
(952, 'FEJ', 'SNOU', 'Feijo Airport', NULL, 'BR', 'Acre', -8.1408300, -70.3472000, 'active', '2026-01-31 19:09:12', '2026-01-31 19:09:12'),
(953, 'RBR', 'SBRB', 'Placido de Castro International Airport', NULL, 'BR', 'Acre', -9.8688900, -67.8981000, 'active', '2026-01-31 19:09:12', '2026-01-31 19:09:12'),
(954, 'TRQ', 'SBTK', 'Jose Galera dos Santos Airport', NULL, 'BR', 'Acre', -8.1552600, -70.7833000, 'active', '2026-01-31 19:09:12', '2026-01-31 19:09:12'),
(955, 'ZMD', 'SWSN', 'Sena Madureira Airport', NULL, 'BR', 'Acre', -9.1160000, -68.6108000, 'active', '2026-01-31 19:09:13', '2026-01-31 19:09:13'),
(956, 'APQ', 'SNAL', 'Arapiraca Airport', NULL, 'BR', 'Alagoas', -9.7753600, -36.6292000, 'active', '2026-01-31 19:09:13', '2026-01-31 19:09:13'),
(957, 'MCZ', 'SBMO', 'Zumbi dos Palmares International Airport', NULL, 'BR', 'Alagoas', -9.5108100, -35.7917000, 'active', '2026-01-31 19:09:13', '2026-01-31 19:09:13'),
(958, 'MCP', 'SBMQ', 'Alberto Alcolumbre International Airport', NULL, 'BR', 'Amapa', 0.0506640, -51.0722000, 'active', '2026-01-31 19:09:14', '2026-01-31 19:09:14'),
(959, 'OYK', 'SBOI', 'Oiapoque Airport', NULL, 'BR', 'Amapa', 3.8554900, -51.7969000, 'active', '2026-01-31 19:09:14', '2026-01-31 19:09:14'),
(960, 'BAZ', 'SWBC', 'Barcelos Airport', NULL, 'BR', 'Amazonas', -0.9812920, -62.9196000, 'active', '2026-01-31 19:09:14', '2026-01-31 19:09:14'),
(961, 'BCR', 'SWNK', 'Novo Campo Airport', NULL, 'BR', 'Amazonas', -8.8345600, -67.3124000, 'active', '2026-01-31 19:09:15', '2026-01-31 19:09:15'),
(962, 'CAF', 'SWCA', 'Carauari Airport', NULL, 'BR', 'Amazonas', -4.8715200, -66.8975000, 'active', '2026-01-31 19:09:15', '2026-01-31 19:09:15'),
(963, 'CIZ', 'SWKO', 'Coari Airport', NULL, 'BR', 'Amazonas', -4.1340600, -63.1326000, 'active', '2026-01-31 19:09:15', '2026-01-31 19:09:15'),
(964, 'ERN', 'SWEI', 'Eirunepe Airport (Amaury Feitosa Tomaz Airport)', NULL, 'BR', 'Amazonas', -6.6395300, -69.8798000, 'active', '2026-01-31 19:09:16', '2026-01-31 19:09:16'),
(965, 'FBA', 'SWOB', 'Fonte Boa Airport', NULL, 'BR', 'Amazonas', -2.5326100, -66.0832000, 'active', '2026-01-31 19:09:16', '2026-01-31 19:09:16'),
(966, 'HUW', 'SWHT', 'Francisco Correa da Cruz Airport', NULL, 'BR', 'Amazonas', -7.5321200, -63.0721000, 'active', '2026-01-31 19:09:16', '2026-01-31 19:09:16'),
(967, 'IPG', 'SWII', 'Ipiranga Airport', NULL, 'BR', 'Amazonas', -2.9390700, -69.6940000, 'active', '2026-01-31 19:09:17', '2026-01-31 19:09:17'),
(968, 'IRZ', 'SWTP', 'Tapuruquara Airport', NULL, 'BR', 'Amazonas', -0.3786000, -64.9923000, 'active', '2026-01-31 19:09:17', '2026-01-31 19:09:17'),
(969, 'ITA', 'SBIC', 'Itacoatiara Airport', NULL, 'BR', 'Amazonas', -3.1272600, -58.4812000, 'active', '2026-01-31 19:09:17', '2026-01-31 19:09:17'),
(970, 'LBR', 'SWLB', 'Labrea Airport', NULL, 'BR', 'Amazonas', -7.2789700, -64.7695000, 'active', '2026-01-31 19:09:18', '2026-01-31 19:09:18'),
(971, 'MAO', 'SBEG', 'Eduardo Gomes International Airport', NULL, 'BR', 'Amazonas', -3.0386100, -60.0497000, 'active', '2026-01-31 19:09:18', '2026-01-31 19:09:18'),
(972, 'MBZ', 'SWMW', 'Maues Airport', NULL, 'BR', 'Amazonas', -3.3721700, -57.7248000, 'active', '2026-01-31 19:09:18', '2026-01-31 19:09:18'),
(973, 'MNX', 'SBMY', 'Manicore Airport', NULL, 'BR', 'Amazonas', -5.8113800, -61.2783000, 'active', '2026-01-31 19:09:19', '2026-01-31 19:09:19'),
(974, 'NVP', 'SWNA', 'Novo Aripuana Airport', NULL, 'BR', 'Amazonas', -5.1180300, -60.3649000, 'active', '2026-01-31 19:09:19', '2026-01-31 19:09:19'),
(975, 'OLC', 'SDCG', 'Senadora Eunice Michiles Airport', NULL, 'BR', 'Amazonas', -3.4679300, -68.9204000, 'active', '2026-01-31 19:09:20', '2026-01-31 19:09:20'),
(976, 'PIN', 'SWPI', 'Julio Belem', NULL, 'BR', 'Amazonas', -2.6730200, -56.7772000, 'active', '2026-01-31 19:09:20', '2026-01-31 19:09:20');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(977, 'PLL', 'SBMN', 'Manaus Air Force Base', NULL, 'BR', 'Amazonas', -3.1460400, -59.9863000, 'active', '2026-01-31 19:09:20', '2026-01-31 19:09:20'),
(978, 'RBB', 'SWBR', 'Borba Airport', NULL, 'BR', 'Amazonas', -4.4063400, -59.6024000, 'active', '2026-01-31 19:09:21', '2026-01-31 19:09:21'),
(979, 'SJL', 'SBUA', 'Sao Gabriel da Cachoeira Airport', NULL, 'BR', 'Amazonas', -0.1483500, -66.9855000, 'active', '2026-01-31 19:09:21', '2026-01-31 19:09:21'),
(980, 'TBT', 'SBTT', 'Tabatinga International Airport', NULL, 'BR', 'Amazonas', -4.2556700, -69.9358000, 'active', '2026-01-31 19:09:21', '2026-01-31 19:09:21'),
(981, 'TFF', 'SBTF', 'Tefe Airport', NULL, 'BR', 'Amazonas', -3.3829400, -64.7241000, 'active', '2026-01-31 19:09:22', '2026-01-31 19:09:22'),
(982, 'BMS', 'SNBU', 'Socrates Mariani Bittencourt Airport', NULL, 'BR', 'Bahia', -14.2554000, -41.8175000, 'active', '2026-01-31 19:09:22', '2026-01-31 19:09:22'),
(983, 'BPS', 'SBPS', 'Porto Seguro Airport', NULL, 'BR', 'Bahia', -16.4386000, -39.0809000, 'active', '2026-01-31 19:09:22', '2026-01-31 19:09:22'),
(984, 'BQQ', 'SNBX', 'Barra Airport (Brazil)', NULL, 'BR', 'Bahia', -11.0808000, -43.1475000, 'active', '2026-01-31 19:09:23', '2026-01-31 19:09:23'),
(985, 'BRA', 'SNBR', 'Barreiras Airport', NULL, 'BR', 'Bahia', -12.0789000, -45.0090000, 'active', '2026-01-31 19:09:23', '2026-01-31 19:09:23'),
(986, 'BVM', 'SNBL', 'Belmonte Airport', NULL, 'BR', 'Bahia', -15.8717000, -38.8719000, 'active', '2026-01-31 19:09:23', '2026-01-31 19:09:23'),
(987, 'CNV', 'SNED', 'Canavieiras Airport', NULL, 'BR', 'Bahia', -15.6670000, -38.9547000, 'active', '2026-01-31 19:09:24', '2026-01-31 19:09:24'),
(988, 'CRQ', 'SBCV', 'Caravelas Airport', NULL, 'BR', 'Bahia', -17.6523000, -39.2531000, 'active', '2026-01-31 19:09:24', '2026-01-31 19:09:24'),
(989, 'FEC', 'SNJD', 'Feira de Santana Airport (Gov. Joao Durval Carneiro Airport)', NULL, 'BR', 'Bahia', -12.2003000, -38.9068000, 'active', '2026-01-31 19:09:24', '2026-01-31 19:09:24'),
(990, 'GNM', 'SNGI', 'Guanambi Airport', NULL, 'BR', 'Bahia', -14.2082000, -42.7461000, 'active', '2026-01-31 19:09:25', '2026-01-31 19:09:25'),
(991, 'IOS', 'SBIL', 'Ilheus Jorge Amado Airport', NULL, 'BR', 'Bahia', -14.8160000, -39.0332000, 'active', '2026-01-31 19:09:25', '2026-01-31 19:09:25'),
(992, 'IPU', 'SNIU', 'Ipiau Airport', NULL, 'BR', 'Bahia', -14.1339000, -39.7339000, 'active', '2026-01-31 19:09:25', '2026-01-31 19:09:25'),
(993, 'IRE', 'SNIC', 'Irece Airport', NULL, 'BR', 'Bahia', -11.3399000, -41.8470000, 'active', '2026-01-31 19:09:26', '2026-01-31 19:09:26'),
(994, 'ITE', 'SNZW', 'Itubera Airport', NULL, 'BR', 'Bahia', -13.7322000, -39.1417000, 'active', '2026-01-31 19:09:26', '2026-01-31 19:09:26'),
(995, 'ITN', 'SNHA', 'Itabuna Airport', NULL, 'BR', 'Bahia', -14.8105000, -39.2904000, 'active', '2026-01-31 19:09:26', '2026-01-31 19:09:26'),
(996, 'JCM', 'SNJB', 'Jacobina Airport', NULL, 'BR', 'Bahia', -11.1632000, -40.5531000, 'active', '2026-01-31 19:09:27', '2026-01-31 19:09:27'),
(997, 'JEQ', 'SNJK', 'Jequie Airport', NULL, 'BR', 'Bahia', -13.8777000, -40.0716000, 'active', '2026-01-31 19:09:27', '2026-01-31 19:09:27'),
(998, 'LAZ', 'SBLP', 'Bom Jesus da Lapa Airport', NULL, 'BR', 'Bahia', -13.2621000, -43.4081000, 'active', '2026-01-31 19:09:27', '2026-01-31 19:09:27'),
(999, 'LEC', 'SBLE', 'Coronel Horacio de Mattos Airport', NULL, 'BR', 'Bahia', -12.4823000, -41.2770000, 'active', '2026-01-31 19:09:28', '2026-01-31 19:09:28'),
(1000, 'MVS', 'SNMU', 'Mucuri Airport', NULL, 'BR', 'Bahia', -18.0489000, -39.8642000, 'active', '2026-01-31 19:09:28', '2026-01-31 19:09:28'),
(1001, 'MXQ', NULL, 'Terceira Praia Cairu Airport', NULL, 'BR', 'Bahia', -13.3866000, -38.9086000, 'active', '2026-01-31 19:09:28', '2026-01-31 19:09:28'),
(1002, 'PAV', 'SBUF', 'Paulo Afonso Airport', NULL, 'BR', 'Bahia', -9.4008800, -38.2506000, 'active', '2026-01-31 19:09:29', '2026-01-31 19:09:29'),
(1003, 'PDF', 'SNRD', 'Prado Airport', NULL, 'BR', 'Bahia', -17.2967000, -39.2712000, 'active', '2026-01-31 19:09:29', '2026-01-31 19:09:29'),
(1004, 'SSA', 'SBSV', 'Deputado Luis Eduardo Magalhaes International Airport', NULL, 'BR', 'Bahia', -12.9086000, -38.3225000, 'active', '2026-01-31 19:09:29', '2026-01-31 19:09:29'),
(1005, 'TXF', 'SNTF', 'Teixeira de Freitas Airport (9 de maio Airport)', NULL, 'BR', 'Bahia', -17.5245000, -39.6685000, 'active', '2026-01-31 19:09:30', '2026-01-31 19:09:30'),
(1006, 'UNA', 'SBTC', 'Una-Comandatuba Airport', NULL, 'BR', 'Bahia', -15.3552000, -38.9990000, 'active', '2026-01-31 19:09:30', '2026-01-31 19:09:30'),
(1007, 'VAL', 'SNVB', 'Valenca Airport', NULL, 'BR', 'Bahia', -13.2965000, -38.9924000, 'active', '2026-01-31 19:09:30', '2026-01-31 19:09:30'),
(1008, 'VDC', 'SBQV', 'Pedro Otacilio Figueiredo Airport', NULL, 'BR', 'Bahia', -14.8628000, -40.8631000, 'active', '2026-01-31 19:09:31', '2026-01-31 19:09:31'),
(1009, 'ARX', 'SBAC', 'Aracati Airport', NULL, 'BR', 'Ceara', -4.5686100, -37.8047000, 'active', '2026-01-31 19:09:31', '2026-01-31 19:09:31'),
(1010, 'CMC', 'SNWC', 'Camocim Airport', NULL, 'BR', 'Ceara', -2.8961800, -40.8580000, 'active', '2026-01-31 19:09:31', '2026-01-31 19:09:31'),
(1011, 'FOR', 'SBFZ', 'Pinto Martins - Fortaleza International Airport', NULL, 'BR', 'Ceara', -3.7762800, -38.5326000, 'active', '2026-01-31 19:09:32', '2026-01-31 19:09:32'),
(1012, 'JCS', NULL, 'Crateus - Dr. Lucio Lima Airport', NULL, 'BR', 'Ceara', -5.2125000, -40.7047000, 'active', '2026-01-31 19:09:32', '2026-01-31 19:09:32'),
(1013, 'JDO', 'SBJU', 'Juazeiro do Norte Airport', NULL, 'BR', 'Ceara', -7.2189600, -39.2701000, 'active', '2026-01-31 19:09:33', '2026-01-31 19:09:33'),
(1014, 'JJD', 'SBJE', 'Comte. Ariston Pessoa Regional Airport', NULL, 'BR', 'Ceara', -2.9066700, -40.3581000, 'active', '2026-01-31 19:09:33', '2026-01-31 19:09:33'),
(1015, 'JSB', NULL, 'Sao Benedito - Walfrido Salmito de Almeida Airport', NULL, 'BR', 'Ceara', -4.0432000, -40.8861000, 'active', '2026-01-31 19:09:33', '2026-01-31 19:09:33'),
(1016, 'JSO', NULL, 'Sobral - Coronel Virgilio Tavora Airport', NULL, 'BR', 'Ceara', -3.6807000, -40.3403000, 'active', '2026-01-31 19:09:34', '2026-01-31 19:09:34'),
(1017, 'QIG', NULL, 'Iguatu Airport', NULL, 'BR', 'Ceara', -6.3480000, -39.2943000, 'active', '2026-01-31 19:09:34', '2026-01-31 19:09:34'),
(1018, 'BSB', 'SBBR', 'Brasilia International Airport (Presidente J. Kubitschek Int\'l Airport)', NULL, 'BR', 'Distrito Federal', -15.8692000, -47.9208000, 'active', '2026-01-31 19:09:34', '2026-01-31 19:09:34'),
(1019, 'CDI', 'SNKI', 'Cachoeiro de Itapemirim Airport (Raimundo de Andrade Airport)', NULL, 'BR', 'Espirito Santo', -20.8343000, -41.1856000, 'active', '2026-01-31 19:09:35', '2026-01-31 19:09:35'),
(1020, 'GUZ', 'SNGA', 'Guarapari Airport', NULL, 'BR', 'Espirito Santo', -20.6465000, -40.4919000, 'active', '2026-01-31 19:09:35', '2026-01-31 19:09:35'),
(1021, 'LHN', NULL, 'Linhares-Antonio Edson De Azevedo Lima Airport', NULL, 'BR', 'Espirito Santo', -19.3580000, -40.0699000, 'active', '2026-01-31 19:09:35', '2026-01-31 19:09:35'),
(1022, 'SBJ', 'SNMX', 'Sao Mateus Airport', NULL, 'BR', 'Espirito Santo', -18.7213000, -39.8337000, 'active', '2026-01-31 19:09:36', '2026-01-31 19:09:36'),
(1023, 'VIX', 'SBVT', 'Eurico de Aguiar Salles Airport', NULL, 'BR', 'Espirito Santo', -20.2581000, -40.2864000, 'active', '2026-01-31 19:09:36', '2026-01-31 19:09:36'),
(1024, 'APS', 'SWNS', 'Anapolis Airport', NULL, 'BR', 'Goias', -16.3623000, -48.9271000, 'active', '2026-01-31 19:09:36', '2026-01-31 19:09:36'),
(1025, 'ARS', 'SWEC', 'Aragarcas Airport', NULL, 'BR', 'Goias', -15.8994000, -52.2411000, 'active', '2026-01-31 19:09:37', '2026-01-31 19:09:37'),
(1026, 'CLV', 'SBCN', 'Caldas Novas Airport', NULL, 'BR', 'Goias', -17.7253000, -48.6075000, 'active', '2026-01-31 19:09:37', '2026-01-31 19:09:37'),
(1027, 'GYN', 'SBGO', 'Santa Genoveva Airport', NULL, 'BR', 'Goias', -16.6320000, -49.2207000, 'active', '2026-01-31 19:09:37', '2026-01-31 19:09:37'),
(1028, 'ITR', 'SBIT', 'Itumbiara Airport', NULL, 'BR', 'Goias', -18.4447000, -49.2134000, 'active', '2026-01-31 19:09:38', '2026-01-31 19:09:38'),
(1029, 'JTI', 'SWJW', 'Jatai Airport', NULL, 'BR', 'Goias', -17.8299000, -51.7730000, 'active', '2026-01-31 19:09:38', '2026-01-31 19:09:38'),
(1030, 'MQH', 'SBMC', 'Minacu Airport', NULL, 'BR', 'Goias', -13.5491000, -48.1953000, 'active', '2026-01-31 19:09:38', '2026-01-31 19:09:38'),
(1031, 'NQL', 'SWNQ', 'Niquelandia Air', NULL, 'BR', 'Goias', -14.4349000, -48.4915000, 'active', '2026-01-31 19:09:39', '2026-01-31 19:09:39'),
(1032, 'RVD', 'SWLC', 'General Leite de Castro Airport', NULL, 'BR', 'Goias', -17.8347000, -50.9561000, 'active', '2026-01-31 19:09:39', '2026-01-31 19:09:39'),
(1033, 'SQM', 'SWUA', 'Sao Miguel do Araguaia Airport', NULL, 'BR', 'Goias', -13.3313000, -50.1976000, 'active', '2026-01-31 19:09:39', '2026-01-31 19:09:39'),
(1034, 'TLZ', 'SWKT', 'Catalao Airport', NULL, 'BR', 'Goias', -18.2168000, -47.8997000, 'active', '2026-01-31 19:09:40', '2026-01-31 19:09:40'),
(1035, 'APY', 'SNAI', 'Alto Parnaiba Airport', NULL, 'BR', 'Maranhao', -9.0836100, -45.9506000, 'active', '2026-01-31 19:09:40', '2026-01-31 19:09:40'),
(1036, 'BDC', 'SNBC', 'Barra do Corda Airport', NULL, 'BR', 'Maranhao', -5.5025000, -45.2158000, 'active', '2026-01-31 19:09:40', '2026-01-31 19:09:40'),
(1037, 'BRB', 'SBRR', 'Barreirinhas Airport', NULL, 'BR', 'Maranhao', -2.7566300, -42.8057000, 'active', '2026-01-31 19:09:41', '2026-01-31 19:09:41'),
(1038, 'BSS', 'SNBS', 'Balsas Airport', NULL, 'BR', 'Maranhao', -7.5260300, -46.0533000, 'active', '2026-01-31 19:09:41', '2026-01-31 19:09:41'),
(1039, 'CLN', 'SBCI', 'Carolina Airport', NULL, 'BR', 'Maranhao', -7.3204400, -47.4587000, 'active', '2026-01-31 19:09:41', '2026-01-31 19:09:41'),
(1040, 'CPU', NULL, 'Cururupu Airport', NULL, 'BR', 'Maranhao', -1.8211100, -44.8669000, 'active', '2026-01-31 19:09:42', '2026-01-31 19:09:42'),
(1041, 'CTP', 'SNCP', 'Carutapera Airport', NULL, 'BR', 'Maranhao', -1.2502800, -46.0172000, 'active', '2026-01-31 19:09:42', '2026-01-31 19:09:42'),
(1042, 'GMS', 'SNGM', 'Guimaraes Airport', NULL, 'BR', 'Maranhao', -2.1094400, -44.6511000, 'active', '2026-01-31 19:09:42', '2026-01-31 19:09:42'),
(1043, 'IMP', 'SBIZ', 'Imperatriz Airport (Prefeito Renato Moreira Airport)', NULL, 'BR', 'Maranhao', -5.5312900, -47.4600000, 'active', '2026-01-31 19:09:43', '2026-01-31 19:09:43'),
(1044, 'PDR', NULL, 'Presidente Dutra Airport', NULL, 'BR', 'Maranhao', -5.3098000, -44.4810000, 'active', '2026-01-31 19:09:43', '2026-01-31 19:09:43'),
(1045, 'PHI', 'SNYE', 'Pinheiro Airport', NULL, 'BR', 'Maranhao', -2.4836100, -45.0672000, 'active', '2026-01-31 19:09:43', '2026-01-31 19:09:43'),
(1046, 'SLZ', 'SBSL', 'Marechal Cunha Machado International Airport', NULL, 'BR', 'Maranhao', -2.5853600, -44.2341000, 'active', '2026-01-31 19:09:44', '2026-01-31 19:09:44'),
(1047, 'BYO', 'SBDB', 'Bonito Airport', NULL, 'BR', 'Mato Grosso do Sul', -21.2473000, -56.4525000, 'active', '2026-01-31 19:09:44', '2026-01-31 19:09:44'),
(1048, 'CGR', 'SBCG', 'Campo Grande International Airport', NULL, 'BR', 'Mato Grosso do Sul', -20.4687000, -54.6725000, 'active', '2026-01-31 19:09:44', '2026-01-31 19:09:44'),
(1049, 'CMG', 'SBCR', 'Corumba International Airport', NULL, 'BR', 'Mato Grosso do Sul', -19.0119000, -57.6714000, 'active', '2026-01-31 19:09:45', '2026-01-31 19:09:45'),
(1050, 'CSS', 'SSCL', 'Cassilandia Airport', NULL, 'BR', 'Mato Grosso do Sul', -19.1464000, -51.6853000, 'active', '2026-01-31 19:09:45', '2026-01-31 19:09:45'),
(1051, 'DOU', 'SSDO', 'Dourados Airport (Francisco de Matos Pereira Airport)', NULL, 'BR', 'Mato Grosso do Sul', -22.2019000, -54.9266000, 'active', '2026-01-31 19:09:45', '2026-01-31 19:09:45'),
(1052, 'PBB', 'SSPN', 'Paranaiba Airport', NULL, 'BR', 'Mato Grosso do Sul', -19.6512000, -51.1994000, 'active', '2026-01-31 19:09:46', '2026-01-31 19:09:46'),
(1053, 'PMG', 'SBPP', 'Ponta Pora International Airport', NULL, 'BR', 'Mato Grosso do Sul', -22.5496000, -55.7026000, 'active', '2026-01-31 19:09:46', '2026-01-31 19:09:46'),
(1054, 'TJL', 'SBTG', 'Plinio Alarcom Airport', NULL, 'BR', 'Mato Grosso do Sul', -20.7542000, -51.6842000, 'active', '2026-01-31 19:09:47', '2026-01-31 19:09:47'),
(1055, 'AFL', 'SBAT', 'Alta Floresta Airport', NULL, 'BR', 'Mato Grosso', -9.8663900, -56.1050000, 'active', '2026-01-31 19:09:47', '2026-01-31 19:09:47'),
(1056, 'AIR', 'SSOU', 'Aripuana Airport', NULL, 'BR', 'Mato Grosso', -10.1883000, -59.4573000, 'active', '2026-01-31 19:09:47', '2026-01-31 19:09:47'),
(1057, 'AZL', 'SWTU', 'Fazenda Tucunare Airport', NULL, 'BR', 'Mato Grosso', -13.4655000, -58.8669000, 'active', '2026-01-31 19:09:48', '2026-01-31 19:09:48'),
(1058, 'BPG', 'SBBW', 'Barra do Garcas Airport', NULL, 'BR', 'Mato Grosso', -15.8613000, -52.3889000, 'active', '2026-01-31 19:09:48', '2026-01-31 19:09:48'),
(1059, 'CCX', 'SWKC', 'Caceres Airport', NULL, 'BR', 'Mato Grosso', -16.0436000, -57.6299000, 'active', '2026-01-31 19:09:48', '2026-01-31 19:09:48'),
(1060, 'CFO', NULL, 'Confresa Airport', NULL, 'BR', 'Mato Grosso', -10.6344000, -51.5636000, 'active', '2026-01-31 19:09:49', '2026-01-31 19:09:49'),
(1061, 'CGB', 'SBCY', 'Marechal Rondon International Airport', NULL, 'BR', 'Mato Grosso', -15.6529000, -56.1167000, 'active', '2026-01-31 19:09:49', '2026-01-31 19:09:49'),
(1062, 'CQA', 'SWEK', 'Canarana Airport', NULL, 'BR', 'Mato Grosso', -13.5744000, -52.2706000, 'active', '2026-01-31 19:09:49', '2026-01-31 19:09:49'),
(1063, 'DMT', 'SWDM', 'Diamantino Airport', NULL, 'BR', 'Mato Grosso', -14.3769000, -56.4004000, 'active', '2026-01-31 19:09:50', '2026-01-31 19:09:50'),
(1064, 'GGB', 'SWHP', 'Agua Boa Airport', NULL, 'BR', 'Mato Grosso', -14.0194000, -52.1522000, 'active', '2026-01-31 19:09:50', '2026-01-31 19:09:50'),
(1065, 'JIA', 'SWJN', 'Juina Airport', NULL, 'BR', 'Mato Grosso', -11.4194000, -58.7017000, 'active', '2026-01-31 19:09:50', '2026-01-31 19:09:50'),
(1066, 'JRN', 'SWJU', 'Juruena Airport', NULL, 'BR', 'Mato Grosso', -10.3058000, -58.4894000, 'active', '2026-01-31 19:09:51', '2026-01-31 19:09:51'),
(1067, 'JUA', 'SIZX', 'Mauro Luiz Frizon Airport', NULL, 'BR', 'Mato Grosso', -11.2966000, -57.5495000, 'active', '2026-01-31 19:09:51', '2026-01-31 19:09:51'),
(1068, 'LCB', NULL, 'Pontes e Lacerda Airport', NULL, 'BR', 'Mato Grosso', -15.1934000, -59.3848000, 'active', '2026-01-31 19:09:51', '2026-01-31 19:09:51'),
(1069, 'LVR', 'SILC', 'Bom Futuro Municipal Airport', NULL, 'BR', 'Mato Grosso', -13.0379000, -55.9502000, 'active', '2026-01-31 19:09:52', '2026-01-31 19:09:52'),
(1070, 'MBK', 'SWXM', 'Orlando Villas-Boas Regional Airport', NULL, 'BR', 'Mato Grosso', -10.1703000, -54.9528000, 'active', '2026-01-31 19:09:52', '2026-01-31 19:09:52'),
(1071, 'MTG', 'SWVB', 'Mato Grosso Airport', NULL, 'BR', 'Mato Grosso', -14.9942000, -59.9458000, 'active', '2026-01-31 19:09:52', '2026-01-31 19:09:52'),
(1072, 'NOK', 'SWXV', 'Nova Xavantina Airport', NULL, 'BR', 'Mato Grosso', -14.6983000, -52.3464000, 'active', '2026-01-31 19:09:53', '2026-01-31 19:09:53'),
(1073, 'OPS', 'SWSI', 'Presidente Joao Figueiredo Airport', NULL, 'BR', 'Mato Grosso', -11.8850000, -55.5861000, 'active', '2026-01-31 19:09:53', '2026-01-31 19:09:53'),
(1074, 'OTT', NULL, 'Andre Maggi Airport', NULL, 'BR', 'Mato Grosso', -9.8986100, -58.5819000, 'active', '2026-01-31 19:09:54', '2026-01-31 19:09:54'),
(1075, 'PBV', 'SWPG', 'Aeroporto de Porto dos Gauchos Airport', NULL, 'BR', 'Mato Grosso', -11.5404000, -57.3782000, 'active', '2026-01-31 19:09:54', '2026-01-31 19:09:54'),
(1076, 'PBX', 'SWPQ', 'Fazenda Piraguassu Airport', NULL, 'BR', 'Mato Grosso', -10.8611000, -51.6850000, 'active', '2026-01-31 19:09:54', '2026-01-31 19:09:54'),
(1077, 'ROO', 'SWRD', 'Maestro Marinho Franco Airport', NULL, 'BR', 'Mato Grosso', -16.5860000, -54.7248000, 'active', '2026-01-31 19:09:55', '2026-01-31 19:09:55'),
(1078, 'SMT', NULL, 'Adolino Bedin Sorriso Airport', NULL, 'BR', 'Mato Grosso', -12.4795000, -55.6763000, 'active', '2026-01-31 19:09:55', '2026-01-31 19:09:55'),
(1079, 'STZ', 'SWST', 'Santa Terezinha Airport', NULL, 'BR', 'Mato Grosso', -10.4647000, -50.5186000, 'active', '2026-01-31 19:09:55', '2026-01-31 19:09:55'),
(1080, 'SWM', NULL, 'Suia-Missu Airport', NULL, 'BR', 'Mato Grosso', -11.6717000, -51.4347000, 'active', '2026-01-31 19:09:56', '2026-01-31 19:09:56'),
(1081, 'SXO', 'SWFX', 'Sao Felix do Araguaia', NULL, 'BR', 'Mato Grosso', -11.6324000, -50.6896000, 'active', '2026-01-31 19:09:56', '2026-01-31 19:09:56'),
(1082, 'TGQ', 'SWTS', 'Tangara da Serra Airport', NULL, 'BR', 'Mato Grosso', -14.6620000, -57.4435000, 'active', '2026-01-31 19:09:56', '2026-01-31 19:09:56'),
(1083, 'VLP', 'SWVC', 'Vila Rica Municipal Airport', NULL, 'BR', 'Mato Grosso', -9.9794400, -51.1422000, 'active', '2026-01-31 19:09:57', '2026-01-31 19:09:57'),
(1084, 'AAX', 'SBAX', 'Araxa Airport', NULL, 'BR', 'Minas Gerais', -19.5632000, -46.9604000, 'active', '2026-01-31 19:09:57', '2026-01-31 19:09:57'),
(1085, 'AMJ', 'SNAR', 'Almenara Airport', NULL, 'BR', 'Minas Gerais', -16.1839000, -40.6672000, 'active', '2026-01-31 19:09:57', '2026-01-31 19:09:57'),
(1086, 'CNF', 'SBCF', 'Tancredo Neves International Airport', NULL, 'BR', 'Minas Gerais', -19.6336000, -43.9686000, 'active', '2026-01-31 19:09:58', '2026-01-31 19:09:58'),
(1087, 'DIQ', 'SNDV', 'Divinopolis Airport (Brigadeiro Cabral Airport)', NULL, 'BR', 'Minas Gerais', -20.1807000, -44.8709000, 'active', '2026-01-31 19:09:58', '2026-01-31 19:09:58'),
(1088, 'DTI', 'SNDT', 'Diamantina Airport', NULL, 'BR', 'Minas Gerais', -18.2320000, -43.6504000, 'active', '2026-01-31 19:09:58', '2026-01-31 19:09:58'),
(1089, 'ESI', NULL, 'Espinosa Airport', NULL, 'BR', 'Minas Gerais', -14.9337000, -42.8100000, 'active', '2026-01-31 19:09:59', '2026-01-31 19:09:59'),
(1090, 'GVR', 'SBGV', 'Coronel Altino Machado de Oliveira Airport', NULL, 'BR', 'Minas Gerais', -18.8952000, -41.9822000, 'active', '2026-01-31 19:09:59', '2026-01-31 19:09:59'),
(1091, 'IAL', NULL, 'Salinas Airport', NULL, 'BR', 'Minas Gerais', -16.2085000, -42.3225000, 'active', '2026-01-31 19:09:59', '2026-01-31 19:09:59'),
(1092, 'IPN', 'SBIP', 'Vale do Aco Regional Airport', NULL, 'BR', 'Minas Gerais', -19.4707000, -42.4876000, 'active', '2026-01-31 19:10:00', '2026-01-31 19:10:00'),
(1093, 'ITI', NULL, 'Itambacuri Airport', NULL, 'BR', 'Minas Gerais', -8.7000000, -51.1742000, 'active', '2026-01-31 19:10:00', '2026-01-31 19:10:00'),
(1094, 'IZA', 'SBZM', 'Presidente Itamar Franco Airport (Zona da Mata Regional Airport)', NULL, 'BR', 'Minas Gerais', -21.5131000, -43.1731000, 'active', '2026-01-31 19:10:00', '2026-01-31 19:10:00'),
(1095, 'JDF', 'SBJF', 'Francisco Alvares de Assis Airport', NULL, 'BR', 'Minas Gerais', -21.7915000, -43.3868000, 'active', '2026-01-31 19:10:01', '2026-01-31 19:10:01'),
(1096, 'JDR', 'SNJR', 'Prefeito Octavio de Almeida Neves Airport', NULL, 'BR', 'Minas Gerais', -21.0850000, -44.2247000, 'active', '2026-01-31 19:10:01', '2026-01-31 19:10:01'),
(1097, 'JMA', NULL, 'Elias Breder Airport (Manhuacu Regional)', NULL, 'BR', 'Minas Gerais', -20.2643000, -42.1828000, 'active', '2026-01-31 19:10:01', '2026-01-31 19:10:01'),
(1098, 'JNA', 'SNJN', 'Januaria Airport', NULL, 'BR', 'Minas Gerais', -15.4738000, -44.3855000, 'active', '2026-01-31 19:10:02', '2026-01-31 19:10:02'),
(1099, 'LEP', 'SNDN', 'Leopoldina Airport', NULL, 'BR', 'Minas Gerais', -21.4661000, -42.7270000, 'active', '2026-01-31 19:10:02', '2026-01-31 19:10:02'),
(1100, 'MOC', 'SBMK', 'Montes Claros/Mario Ribeiro Airport', NULL, 'BR', 'Minas Gerais', -16.7069000, -43.8189000, 'active', '2026-01-31 19:10:03', '2026-01-31 19:10:03'),
(1101, 'NNU', 'SNNU', 'Nanuque Airport', NULL, 'BR', 'Minas Gerais', -17.8233000, -40.3299000, 'active', '2026-01-31 19:10:03', '2026-01-31 19:10:03'),
(1102, 'PIV', 'SNPX', 'Pirapora Airport', NULL, 'BR', 'Minas Gerais', -17.3169000, -44.8603000, 'active', '2026-01-31 19:10:03', '2026-01-31 19:10:03'),
(1103, 'POJ', 'SNPD', 'Pedro Pereira dos Santos Airport', NULL, 'BR', 'Minas Gerais', -18.6728000, -46.4912000, 'active', '2026-01-31 19:10:04', '2026-01-31 19:10:04'),
(1104, 'POO', 'SBPC', 'Pocos de Caldas Airport', NULL, 'BR', 'Minas Gerais', -21.8430000, -46.5679000, 'active', '2026-01-31 19:10:04', '2026-01-31 19:10:04'),
(1105, 'PPY', 'SNZA', 'Pouso Alegre Airport', NULL, 'BR', 'Minas Gerais', -22.2892000, -45.9191000, 'active', '2026-01-31 19:10:04', '2026-01-31 19:10:04'),
(1106, 'PSW', 'SNOS', 'Municipal José Figueiredo Airport', NULL, 'BR', 'Minas Gerais', -20.7322000, -46.6618000, 'active', '2026-01-31 19:10:05', '2026-01-31 19:10:05'),
(1107, 'PYT', NULL, 'Paracatu Airport', NULL, 'BR', 'Minas Gerais', -17.2416000, -46.8859000, 'active', '2026-01-31 19:10:05', '2026-01-31 19:10:05'),
(1108, 'SSO', 'SNLO', 'Sao Lourenco Airport', NULL, 'BR', 'Minas Gerais', -22.0909000, -45.0445000, 'active', '2026-01-31 19:10:06', '2026-01-31 19:10:06'),
(1109, 'TFL', 'SNTO', 'Teofilo Otoni Airport (Juscelino Kubitscheck Airport)', NULL, 'BR', 'Minas Gerais', -17.8923000, -41.5136000, 'active', '2026-01-31 19:10:06', '2026-01-31 19:10:06'),
(1110, 'UBA', 'SBUR', 'Mario de Almeida Franco Airport', NULL, 'BR', 'Minas Gerais', -19.7647000, -47.9661000, 'active', '2026-01-31 19:10:06', '2026-01-31 19:10:06'),
(1111, 'UDI', 'SBUL', 'Ten. Cel. Av. Cesar Bombonato Airport', NULL, 'BR', 'Minas Gerais', -18.8836000, -48.2253000, 'active', '2026-01-31 19:10:07', '2026-01-31 19:10:07'),
(1112, 'VAG', 'SBVG', 'Major Brigadeiro Trompowsky Airport', NULL, 'BR', 'Minas Gerais', -21.5901000, -45.4733000, 'active', '2026-01-31 19:10:07', '2026-01-31 19:10:07'),
(1113, 'ALT', NULL, 'Alenquer Airport', NULL, 'BR', 'Para', -1.9170000, -54.7231000, 'active', '2026-01-31 19:10:07', '2026-01-31 19:10:07'),
(1114, 'ATM', 'SBHT', 'Altamira Airport', NULL, 'BR', 'Para', -3.2539100, -52.2540000, 'active', '2026-01-31 19:10:08', '2026-01-31 19:10:08'),
(1115, 'BEL', 'SBBE', 'Val de Cans International Airport', NULL, 'BR', 'Para', -1.3792500, -48.4763000, 'active', '2026-01-31 19:10:08', '2026-01-31 19:10:08'),
(1116, 'BVS', 'SNVS', 'Breves Airport', NULL, 'BR', 'Para', -1.6365300, -50.4436000, 'active', '2026-01-31 19:10:08', '2026-01-31 19:10:08'),
(1117, 'CDJ', 'SBAA', 'Conceicao do Araguaia Airport', NULL, 'BR', 'Para', -8.3483500, -49.3015000, 'active', '2026-01-31 19:10:09', '2026-01-31 19:10:09'),
(1118, 'CKS', 'SBCJ', 'Carajas Airport', NULL, 'BR', 'Para', -6.1152800, -50.0014000, 'active', '2026-01-31 19:10:09', '2026-01-31 19:10:09'),
(1119, 'CMP', 'SNKE', 'Santana do Araguaia Airport', NULL, 'BR', 'Para', -9.3199700, -50.3285000, 'active', '2026-01-31 19:10:09', '2026-01-31 19:10:09'),
(1120, 'CMT', NULL, 'Cameta Airport', NULL, 'BR', 'Para', -2.2468000, -49.5600000, 'active', '2026-01-31 19:10:10', '2026-01-31 19:10:10'),
(1121, 'GGF', 'SNYA', 'Almeirim Airport', NULL, 'BR', 'Para', -1.4791700, -52.5781000, 'active', '2026-01-31 19:10:10', '2026-01-31 19:10:10'),
(1122, 'ITB', 'SBIH', 'Itaituba Airport', NULL, 'BR', 'Para', -4.2423400, -56.0007000, 'active', '2026-01-31 19:10:10', '2026-01-31 19:10:10'),
(1123, 'JCR', 'SBEK', 'Jacareacanga Airport', NULL, 'BR', 'Para', -6.2331600, -57.7769000, 'active', '2026-01-31 19:10:11', '2026-01-31 19:10:11'),
(1124, 'JPE', NULL, 'Nagib Demachki Paragominas Municipal Airport', NULL, 'BR', 'Para', -3.0189000, -47.3210000, 'active', '2026-01-31 19:10:11', '2026-01-31 19:10:11'),
(1125, 'MAB', 'SBMA', 'Joao Correa da Rocha Airport', NULL, 'BR', 'Para', -5.3685900, -49.1380000, 'active', '2026-01-31 19:10:11', '2026-01-31 19:10:11'),
(1126, 'MEU', 'SBMD', 'Serra do Areao Airport', NULL, 'BR', 'Para', -0.8898390, -52.6022000, 'active', '2026-01-31 19:10:12', '2026-01-31 19:10:12'),
(1127, 'MTE', 'SNMA', 'Monte Alegre Airport', NULL, 'BR', 'Para', -1.9958000, -54.0742000, 'active', '2026-01-31 19:10:12', '2026-01-31 19:10:12'),
(1128, 'NPR', 'SJNP', 'Novo Progresso Airport', NULL, 'BR', 'Para', -7.1258300, -55.4008000, 'active', '2026-01-31 19:10:12', '2026-01-31 19:10:12'),
(1129, 'OBI', 'SNTI', 'Obidos Airport', NULL, 'BR', 'Para', -1.8671700, -55.5144000, 'active', '2026-01-31 19:10:13', '2026-01-31 19:10:13'),
(1130, 'OIA', 'SDOW', 'Ourilandia do Norte Airport', NULL, 'BR', 'Para', -6.7631000, -51.0499000, 'active', '2026-01-31 19:10:13', '2026-01-31 19:10:13'),
(1131, 'OPP', NULL, 'Salinopolis Airport', NULL, 'BR', 'Para', -0.6942000, -47.3281000, 'active', '2026-01-31 19:10:13', '2026-01-31 19:10:13'),
(1132, 'ORX', 'SNOX', 'Oriximina Airport', NULL, 'BR', 'Para', -1.7140800, -55.8362000, 'active', '2026-01-31 19:10:14', '2026-01-31 19:10:14'),
(1133, 'PTQ', 'SNMZ', 'Porto de Moz Airport', NULL, 'BR', 'Para', -1.7414500, -52.2361000, 'active', '2026-01-31 19:10:14', '2026-01-31 19:10:14'),
(1134, 'RDC', 'SNDC', 'Redencao Airport', NULL, 'BR', 'Para', -8.0332900, -49.9799000, 'active', '2026-01-31 19:10:14', '2026-01-31 19:10:14'),
(1135, 'SFK', 'SNSW', 'Soure Airport', NULL, 'BR', 'Para', -0.6994310, -48.5210000, 'active', '2026-01-31 19:10:15', '2026-01-31 19:10:15'),
(1136, 'STM', 'SBSN', 'Santarem-Maestro Wilson Fonseca Airport', NULL, 'BR', 'Para', -2.4247200, -54.7858000, 'active', '2026-01-31 19:10:15', '2026-01-31 19:10:15'),
(1137, 'SXX', 'SNFX', 'Sao Felix do Xingu Airport', NULL, 'BR', 'Para', -6.6413000, -51.9523000, 'active', '2026-01-31 19:10:15', '2026-01-31 19:10:15'),
(1138, 'TMT', 'SBTB', 'Porto Trombetas Airport', NULL, 'BR', 'Para', -1.4896000, -56.3968000, 'active', '2026-01-31 19:10:16', '2026-01-31 19:10:16'),
(1139, 'TUZ', NULL, 'Tucuma Airport', NULL, 'BR', 'Para', -6.7488000, -51.1478000, 'active', '2026-01-31 19:10:16', '2026-01-31 19:10:16'),
(1140, 'XIG', NULL, 'Xinguara Municipal Airport', NULL, 'BR', 'Para', -7.0906000, -49.9765000, 'active', '2026-01-31 19:10:16', '2026-01-31 19:10:16'),
(1141, 'CJZ', NULL, 'Cajazeiras Pedro Vieira Moreira Regional Airport', NULL, 'BR', 'Paraiba', -6.8813000, -38.6182000, 'active', '2026-01-31 19:10:17', '2026-01-31 19:10:17'),
(1142, 'CPV', 'SBKG', 'Campina Grande Airport (Presidente Joao Suassuna Airport)', NULL, 'BR', 'Paraiba', -7.2699200, -35.8964000, 'active', '2026-01-31 19:10:17', '2026-01-31 19:10:17'),
(1143, 'JPA', 'SBJP', 'Presidente Castro Pinto International Airport', NULL, 'BR', 'Paraiba', -7.1458300, -34.9486000, 'active', '2026-01-31 19:10:17', '2026-01-31 19:10:17'),
(1144, 'JPO', NULL, 'Patos de Paraiba Brigadeiro Firmino Ayres Regional Airport', NULL, 'BR', 'Paraiba', -7.0373000, -37.2517000, 'active', '2026-01-31 19:10:18', '2026-01-31 19:10:18'),
(1145, 'AAG', 'SSYA', 'Avelino Vieira Airport', NULL, 'BR', 'Parana', -24.1039000, -49.7891000, 'active', '2026-01-31 19:10:18', '2026-01-31 19:10:18'),
(1146, 'APU', 'SSAP', 'Apucarana Airport', NULL, 'BR', 'Parana', -23.6095000, -51.3845000, 'active', '2026-01-31 19:10:18', '2026-01-31 19:10:18'),
(1147, 'APX', 'SSOG', 'Arapongas Airport', NULL, 'BR', 'Parana', -23.3529000, -51.4917000, 'active', '2026-01-31 19:10:19', '2026-01-31 19:10:19'),
(1148, 'BFH', 'SBBI', 'Bacacheri Airport', NULL, 'BR', 'Parana', -25.4051000, -49.2320000, 'active', '2026-01-31 19:10:19', '2026-01-31 19:10:19'),
(1149, 'CAC', 'SBCA', 'Cascavel Airport (Adalberto Mendes da Silva Airport)', NULL, 'BR', 'Parana', -25.0003000, -53.5008000, 'active', '2026-01-31 19:10:19', '2026-01-31 19:10:19'),
(1150, 'CBW', 'SSKM', 'Campo Mourao Airport', NULL, 'BR', 'Parana', -24.0092000, -52.3568000, 'active', '2026-01-31 19:10:20', '2026-01-31 19:10:20'),
(1151, 'CKO', 'SSCP', 'Cornelio Procopio Airport', NULL, 'BR', 'Parana', -23.1525000, -50.6025000, 'active', '2026-01-31 19:10:20', '2026-01-31 19:10:20'),
(1152, 'CWB', 'SBCT', 'Afonso Pena International Airport', NULL, 'BR', 'Parana', -25.5285000, -49.1758000, 'active', '2026-01-31 19:10:20', '2026-01-31 19:10:20'),
(1153, 'FBE', 'SSFB', 'Francisco Beltrao Airport (Paulo Abdala Airport)', NULL, 'BR', 'Parana', -26.0592000, -53.0635000, 'active', '2026-01-31 19:10:21', '2026-01-31 19:10:21'),
(1154, 'GGH', 'SSCT', 'Gastao Mesquita Airport', NULL, 'BR', 'Parana', -23.6914000, -52.6422000, 'active', '2026-01-31 19:10:21', '2026-01-31 19:10:21'),
(1155, 'GGJ', 'SSGY', 'Guaira Airport', NULL, 'BR', 'Parana', -24.0797000, -54.1881000, 'active', '2026-01-31 19:10:22', '2026-01-31 19:10:22'),
(1156, 'GPB', 'SBGU', 'Tancredo Thomas de Faria Airport', NULL, 'BR', 'Parana', -25.3875000, -51.5202000, 'active', '2026-01-31 19:10:22', '2026-01-31 19:10:22'),
(1157, 'IGU', 'SBFI', 'Foz do Iguacu International Airport', NULL, 'BR', 'Parana', -25.6003000, -54.4850000, 'active', '2026-01-31 19:10:22', '2026-01-31 19:10:22'),
(1158, 'LDB', 'SBLO', 'Londrina-Governador Jose Richa Airport', NULL, 'BR', 'Parana', -23.3336000, -51.1301000, 'active', '2026-01-31 19:10:23', '2026-01-31 19:10:23'),
(1159, 'MGF', 'SBMG', 'Silvio Name Junior Regional Airport', NULL, 'BR', 'Parana', -23.4761000, -52.0162000, 'active', '2026-01-31 19:10:23', '2026-01-31 19:10:23'),
(1160, 'PGZ', 'SSZW', 'Comte. Antonio Amilton Beraldo Airport', NULL, 'BR', 'Parana', -25.1847000, -50.1441000, 'active', '2026-01-31 19:10:23', '2026-01-31 19:10:23'),
(1161, 'PNG', 'SSPG', 'Santos Dumont Airport', NULL, 'BR', 'Parana', -25.5401000, -48.5312000, 'active', '2026-01-31 19:10:24', '2026-01-31 19:10:24'),
(1162, 'PTO', 'SSPB', 'Juvenal Loureiro Cardoso Airport', NULL, 'BR', 'Parana', -26.2172000, -52.6945000, 'active', '2026-01-31 19:10:24', '2026-01-31 19:10:24'),
(1163, 'PVI', 'SSPI', 'Edu Chaves Airport', NULL, 'BR', 'Parana', -23.0899000, -52.4885000, 'active', '2026-01-31 19:10:24', '2026-01-31 19:10:24'),
(1164, 'TEC', 'SBTL', 'Telemaco Borba Airport', NULL, 'BR', 'Parana', -24.3178000, -50.6516000, 'active', '2026-01-31 19:10:25', '2026-01-31 19:10:25'),
(1165, 'TOW', 'SBTD', 'Luiz dal Canalle Filho Airport', NULL, 'BR', 'Parana', -24.6863000, -53.6975000, 'active', '2026-01-31 19:10:25', '2026-01-31 19:10:25'),
(1166, 'TUR', 'SBTU', 'Tucurui Airport', NULL, 'BR', 'Parana', -3.7860100, -49.7203000, 'active', '2026-01-31 19:10:25', '2026-01-31 19:10:25'),
(1167, 'UMU', 'SSUM', 'Orlando de Carvalho Airport', NULL, 'BR', 'Parana', -23.7987000, -53.3138000, 'active', '2026-01-31 19:10:26', '2026-01-31 19:10:26'),
(1168, 'CAU', 'SNRU', 'Caruaru Airport (Oscar Laranjeiras Airport)', NULL, 'BR', 'Pernambuco', -8.2823900, -36.0135000, 'active', '2026-01-31 19:10:26', '2026-01-31 19:10:26'),
(1169, 'FEN', 'SBFN', 'Fernando de Noronha Airport (Gov. Carlos Wilson Airport)', NULL, 'BR', 'Pernambuco', -3.8549300, -32.4233000, 'active', '2026-01-31 19:10:26', '2026-01-31 19:10:26'),
(1170, 'JAW', NULL, 'Araripina Comandante Mairson Rodrigues Bezerra Airport', NULL, 'BR', 'Pernambuco', -7.5854000, -40.5352000, 'active', '2026-01-31 19:10:27', '2026-01-31 19:10:27'),
(1171, 'PNZ', 'SBPL', 'Senador Nilo Coelho Airport', NULL, 'BR', 'Pernambuco', -9.3624100, -40.5691000, 'active', '2026-01-31 19:10:27', '2026-01-31 19:10:27'),
(1172, 'QGP', 'SNGN', 'Garanhuns Airport', NULL, 'BR', 'Pernambuco', -8.8381000, -36.4696000, 'active', '2026-01-31 19:10:27', '2026-01-31 19:10:27'),
(1173, 'REC', 'SBRF', 'Recife/Guararapes-Gilberto Freyre International Airport', NULL, 'BR', 'Pernambuco', -8.1264900, -34.9236000, 'active', '2026-01-31 19:10:28', '2026-01-31 19:10:28'),
(1174, 'SET', 'SNHS', 'Serra Talhada Santa Magalhaes Regional Airport', NULL, 'BR', 'Pernambuco', -8.0619000, -38.3240000, 'active', '2026-01-31 19:10:28', '2026-01-31 19:10:28'),
(1175, 'FLB', 'SNQG', 'Cangapara Airport', NULL, 'BR', 'Piaui', -6.8463900, -43.0773000, 'active', '2026-01-31 19:10:28', '2026-01-31 19:10:28'),
(1176, 'GDP', 'SNGD', 'Guadalupe Airport', NULL, 'BR', 'Piaui', -6.7822200, -43.5822000, 'active', '2026-01-31 19:10:29', '2026-01-31 19:10:29'),
(1177, 'NSR', NULL, 'Serra da Capivara International Airport', NULL, 'BR', 'Piaui', -9.0807000, -42.6429000, 'active', '2026-01-31 19:10:29', '2026-01-31 19:10:29'),
(1178, 'PCS', 'SNPC', 'Picos Airport', NULL, 'BR', 'Piaui', -7.0620600, -41.5237000, 'active', '2026-01-31 19:10:29', '2026-01-31 19:10:29'),
(1179, 'PHB', 'SBPB', 'Parnaiba-Prefeito Dr. Joao Silva Filho International Airport', NULL, 'BR', 'Piaui', -2.8937500, -41.7320000, 'active', '2026-01-31 19:10:30', '2026-01-31 19:10:30'),
(1180, 'THE', 'SBTE', 'Teresina-Senador Petronio Portel Airport', NULL, 'BR', 'Piaui', -5.0599400, -42.8235000, 'active', '2026-01-31 19:10:30', '2026-01-31 19:10:30'),
(1181, 'MVF', 'SBMS', 'Gov. Dix-Sept Rosado Airport', NULL, 'BR', 'Rio Grande do Norte', -5.2019200, -37.3643000, 'active', '2026-01-31 19:10:30', '2026-01-31 19:10:30'),
(1182, 'NAT', 'SBNT', 'Sao Goncalo do Amarante-Governador Aluizio Alves International Airport', NULL, 'BR', 'Rio Grande do Norte', -5.7680600, -35.3761000, 'active', '2026-01-31 19:10:31', '2026-01-31 19:10:31'),
(1183, 'ALQ', 'SSLT', 'Alegrete Airport', NULL, 'BR', 'Rio Grande do Sul', -29.8127000, -55.8934000, 'active', '2026-01-31 19:10:31', '2026-01-31 19:10:31'),
(1184, 'BGV', NULL, 'Bento Goncalves Airport', NULL, 'BR', 'Rio Grande do Sul', -29.1483000, -51.5364000, 'active', '2026-01-31 19:10:31', '2026-01-31 19:10:31'),
(1185, 'BGX', 'SBBG', 'Comandante Gustavo Kraemer Airport', NULL, 'BR', 'Rio Grande do Sul', -31.3905000, -54.1122000, 'active', '2026-01-31 19:10:32', '2026-01-31 19:10:32'),
(1186, 'CEL', 'SSCN', 'Canela Airport', NULL, 'BR', 'Rio Grande do Sul', -29.3706000, -50.8322000, 'active', '2026-01-31 19:10:32', '2026-01-31 19:10:32'),
(1187, 'CSU', 'SSSC', 'Santa Cruz do Sul Airport', NULL, 'BR', 'Rio Grande do Sul', -29.6841000, -52.4122000, 'active', '2026-01-31 19:10:32', '2026-01-31 19:10:32'),
(1188, 'CTQ', 'SSVP', 'Santa Vitoria do Palmar Airport', NULL, 'BR', 'Rio Grande do Sul', -33.5022000, -53.3442000, 'active', '2026-01-31 19:10:33', '2026-01-31 19:10:33'),
(1189, 'CXJ', 'SBCX', 'Caxias do Sul Airport (Hugo Cantergiani Regional Airport)', NULL, 'BR', 'Rio Grande do Sul', -29.1971000, -51.1875000, 'active', '2026-01-31 19:10:33', '2026-01-31 19:10:33'),
(1190, 'CZB', NULL, 'Carlos Ruhl Airport', NULL, 'BR', 'Rio Grande do Sul', -28.6578000, -53.6106000, 'active', '2026-01-31 19:10:33', '2026-01-31 19:10:33'),
(1191, 'ERM', 'SSER', 'Erechim Airport', NULL, 'BR', 'Rio Grande do Sul', -27.6619000, -52.2683000, 'active', '2026-01-31 19:10:34', '2026-01-31 19:10:34'),
(1192, 'GEL', 'SBNM', 'Sepe Tiaraju Airport', NULL, 'BR', 'Rio Grande do Sul', -28.2817000, -54.1691000, 'active', '2026-01-31 19:10:34', '2026-01-31 19:10:34'),
(1193, 'HRZ', 'SSHZ', 'Horizontina Airport', NULL, 'BR', 'Rio Grande do Sul', -27.6383000, -54.3391000, 'active', '2026-01-31 19:10:34', '2026-01-31 19:10:34'),
(1194, 'IJU', 'SSIJ', 'Joao Batista Bos Filho Airport', NULL, 'BR', 'Rio Grande do Sul', -28.3687000, -53.8466000, 'active', '2026-01-31 19:10:35', '2026-01-31 19:10:35'),
(1195, 'ITQ', 'SSIQ', 'Itaqui Airport', NULL, 'BR', 'Rio Grande do Sul', -29.1731000, -56.5367000, 'active', '2026-01-31 19:10:35', '2026-01-31 19:10:35'),
(1196, 'LVB', 'SNLB', 'Livramento do Brumado Airport', NULL, 'BR', 'Rio Grande do Sul', -13.6506000, -41.8339000, 'active', '2026-01-31 19:10:35', '2026-01-31 19:10:35'),
(1197, 'PET', 'SBPK', 'Joao Simoes Lopes Neto International Airport', NULL, 'BR', 'Rio Grande do Sul', -31.7184000, -52.3277000, 'active', '2026-01-31 19:10:36', '2026-01-31 19:10:36'),
(1198, 'PFB', 'SBPF', 'Lauro Kurtz Airport', NULL, 'BR', 'Rio Grande do Sul', -28.2440000, -52.3266000, 'active', '2026-01-31 19:10:36', '2026-01-31 19:10:36'),
(1199, 'POA', 'SBPA', 'Salgado Filho International Airport', NULL, 'BR', 'Rio Grande do Sul', -29.9944000, -51.1714000, 'active', '2026-01-31 19:10:36', '2026-01-31 19:10:36'),
(1200, 'QNS', NULL, 'Canoas Air Force Base', NULL, 'BR', 'Rio Grande do Sul', -29.9406000, -51.1509000, 'active', '2026-01-31 19:10:37', '2026-01-31 19:10:37'),
(1201, 'RIA', 'SBSM', 'Santa Maria Airport (Rio Grande do Sul)', NULL, 'BR', 'Rio Grande do Sul', -29.7114000, -53.6882000, 'active', '2026-01-31 19:10:37', '2026-01-31 19:10:37'),
(1202, 'RIG', 'SBRG', 'Rio Grande Regional Airport', NULL, 'BR', 'Rio Grande do Sul', -32.0817000, -52.1633000, 'active', '2026-01-31 19:10:37', '2026-01-31 19:10:37'),
(1203, 'SQY', 'SSRU', 'Sao Lourenco do Sul Airport', NULL, 'BR', 'Rio Grande do Sul', -31.3833000, -52.0328000, 'active', '2026-01-31 19:10:38', '2026-01-31 19:10:38'),
(1204, 'SRA', 'SSZR', 'Santa Rosa Airport (Brazil)', NULL, 'BR', 'Rio Grande do Sul', -27.9067000, -54.5204000, 'active', '2026-01-31 19:10:38', '2026-01-31 19:10:38'),
(1205, 'TSQ', 'SBTR', 'Torres Airport', NULL, 'BR', 'Rio Grande do Sul', -29.4149000, -49.8100000, 'active', '2026-01-31 19:10:38', '2026-01-31 19:10:38'),
(1206, 'URG', 'SBUG', 'Rubem Berta International Airport', NULL, 'BR', 'Rio Grande do Sul', -29.7822000, -57.0382000, 'active', '2026-01-31 19:10:39', '2026-01-31 19:10:39'),
(1207, 'BZC', 'SBBZ', 'Umberto Modiano Airport', NULL, 'BR', 'Rio de Janeiro', -22.7709000, -41.9631000, 'active', '2026-01-31 19:10:39', '2026-01-31 19:10:39'),
(1208, 'CAW', 'SBCP', 'Bartolomeu Lysandro Airport', NULL, 'BR', 'Rio de Janeiro', -21.6983000, -41.3017000, 'active', '2026-01-31 19:10:40', '2026-01-31 19:10:40'),
(1209, 'CFB', 'SBCB', 'Cabo Frio International Airport', NULL, 'BR', 'Rio de Janeiro', -22.9217000, -42.0743000, 'active', '2026-01-31 19:10:40', '2026-01-31 19:10:40'),
(1210, 'GIG', 'SBGL', 'Galeao-Antonio Carlos Jobim International Airport', NULL, 'BR', 'Rio de Janeiro', -22.8100000, -43.2506000, 'active', '2026-01-31 19:10:40', '2026-01-31 19:10:40'),
(1211, 'ITP', 'SDUN', 'Itaperuna Airport', NULL, 'BR', 'Rio de Janeiro', -21.2193000, -41.8759000, 'active', '2026-01-31 19:10:41', '2026-01-31 19:10:41'),
(1212, 'MEA', 'SBME', 'Benedito Lacerda Airport', NULL, 'BR', 'Rio de Janeiro', -22.3430000, -41.7660000, 'active', '2026-01-31 19:10:41', '2026-01-31 19:10:41'),
(1213, 'REZ', 'SDRS', 'Resende Airport', NULL, 'BR', 'Rio de Janeiro', -22.4785000, -44.4803000, 'active', '2026-01-31 19:10:41', '2026-01-31 19:10:41'),
(1214, 'RRJ', 'SBJR', 'Jacarepagua Airport', NULL, 'BR', 'Rio de Janeiro', -22.9878000, -43.3702000, 'active', '2026-01-31 19:10:42', '2026-01-31 19:10:42'),
(1215, 'SDU', 'SBRJ', 'Rio de Janeiro Santos Dumont Airport', NULL, 'BR', 'Rio de Janeiro', -22.9103000, -43.1655000, 'active', '2026-01-31 19:10:42', '2026-01-31 19:10:42'),
(1216, 'AQM', NULL, 'Ariquemes Airport', NULL, 'BR', 'Rondonia', -10.1781000, -62.8256000, 'active', '2026-01-31 19:10:42', '2026-01-31 19:10:42'),
(1217, 'BVH', 'SBVH', 'Vilhena Airport (Brigadeiro Camarao Airport)', NULL, 'BR', 'Rondonia', -12.6944000, -60.0983000, 'active', '2026-01-31 19:10:43', '2026-01-31 19:10:43'),
(1218, 'CQS', 'SWCQ', 'Costa Marques Airport', NULL, 'BR', 'Rondonia', -12.4211000, -64.2516000, 'active', '2026-01-31 19:10:43', '2026-01-31 19:10:43'),
(1219, 'GJM', 'SBGM', 'Guajara-Mirim Airport', NULL, 'BR', 'Rondonia', -10.7864000, -65.2848000, 'active', '2026-01-31 19:10:43', '2026-01-31 19:10:43'),
(1220, 'JPR', 'SWJI', 'Jose Coleto Airport', NULL, 'BR', 'Rondonia', -10.8708000, -61.8465000, 'active', '2026-01-31 19:10:44', '2026-01-31 19:10:44'),
(1221, 'OAL', 'SSKW', 'Capital do Cafe Airport', NULL, 'BR', 'Rondonia', -11.4960000, -61.4508000, 'active', '2026-01-31 19:10:44', '2026-01-31 19:10:44'),
(1222, 'PBQ', 'SWPM', 'Pimenta Bueno Airport', NULL, 'BR', 'Rondonia', -11.6416000, -61.1791000, 'active', '2026-01-31 19:10:44', '2026-01-31 19:10:44'),
(1223, 'PVH', 'SBPV', 'Governador Jorge Teixeira de Oliveira International Airport', NULL, 'BR', 'Rondonia', -8.7092900, -63.9023000, 'active', '2026-01-31 19:10:45', '2026-01-31 19:10:45'),
(1224, 'BVB', 'SBBV', 'Boa Vista International Airport', NULL, 'BR', 'Roraima', 2.8413900, -60.6922000, 'active', '2026-01-31 19:10:45', '2026-01-31 19:10:45'),
(1225, 'AXE', NULL, 'Xanxerê - João Winckler Airport', NULL, 'BR', 'Santa Catarina', -26.8756000, -52.3731000, 'active', '2026-01-31 19:10:45', '2026-01-31 19:10:45'),
(1226, 'BNU', 'SSBL', 'Blumenau Airport', NULL, 'BR', 'Santa Catarina', -26.8306000, -49.0903000, 'active', '2026-01-31 19:10:46', '2026-01-31 19:10:46'),
(1227, 'CCI', 'SSCK', 'Concordia Airport', NULL, 'BR', 'Santa Catarina', -27.1806000, -52.0527000, 'active', '2026-01-31 19:10:46', '2026-01-31 19:10:46'),
(1228, 'CCM', 'SBCM', 'Diomicio Freitas Airport', NULL, 'BR', 'Santa Catarina', -28.7244000, -49.4214000, 'active', '2026-01-31 19:10:46', '2026-01-31 19:10:46'),
(1229, 'CFC', 'SBCD', 'Cacador Airport', NULL, 'BR', 'Santa Catarina', -26.7884000, -50.9398000, 'active', '2026-01-31 19:10:47', '2026-01-31 19:10:47'),
(1230, 'EEA', 'SNCP', 'Planalto Serrano Correia Regional Airport', NULL, 'BR', 'Santa Catarina', -27.6286000, -50.3508000, 'active', '2026-01-31 19:10:47', '2026-01-31 19:10:47'),
(1231, 'FLN', 'SBFL', 'Hercilio Luz International Airport', NULL, 'BR', 'Santa Catarina', -27.6703000, -48.5525000, 'active', '2026-01-31 19:10:47', '2026-01-31 19:10:47'),
(1232, 'JCB', 'SSJA', 'Santa Terezinha Municipal Airport', NULL, 'BR', 'Santa Catarina', -27.1714000, -51.5533000, 'active', '2026-01-31 19:10:48', '2026-01-31 19:10:48'),
(1233, 'JJG', 'SBJA', 'Humberto Ghizzo Bortoluzzi Regional Airport', NULL, 'BR', 'Santa Catarina', -28.6753000, -49.0596000, 'active', '2026-01-31 19:10:48', '2026-01-31 19:10:48'),
(1234, 'JOI', 'SBJV', 'Joinville-Lauro Carneiro de Loyola Airport', NULL, 'BR', 'Santa Catarina', -26.2245000, -48.7974000, 'active', '2026-01-31 19:10:48', '2026-01-31 19:10:48'),
(1235, 'LAJ', 'SBLJ', 'Antonio Correia Pinto de Macedo Airport', NULL, 'BR', 'Santa Catarina', -27.7821000, -50.2815000, 'active', '2026-01-31 19:10:49', '2026-01-31 19:10:49'),
(1236, 'LOI', 'SSLN', 'Helmuth Baungartem Airport', NULL, 'BR', 'Santa Catarina', -27.1600000, -49.5425000, 'active', '2026-01-31 19:10:49', '2026-01-31 19:10:49'),
(1237, 'NVT', 'SBNF', 'Navegantes-Ministro Victor Konder International Airport', NULL, 'BR', 'Santa Catarina', -26.8800000, -48.6514000, 'active', '2026-01-31 19:10:49', '2026-01-31 19:10:49'),
(1238, 'SQX', 'SSOE', 'Helio Wasum Airport', NULL, 'BR', 'Santa Catarina', -26.7816000, -53.5035000, 'active', '2026-01-31 19:10:50', '2026-01-31 19:10:50'),
(1239, 'UVI', 'SSUV', 'Uniao da Vitoria Airport', NULL, 'BR', 'Santa Catarina', -26.2317000, -51.0689000, 'active', '2026-01-31 19:10:50', '2026-01-31 19:10:50'),
(1240, 'VIA', 'SSVI', 'Angelo Ponzoni Municipal Airport', NULL, 'BR', 'Santa Catarina', -26.9997000, -51.1419000, 'active', '2026-01-31 19:10:51', '2026-01-31 19:10:51'),
(1241, 'XAP', 'SBCH', 'Serafin Enoss Bertaso Airport', NULL, 'BR', 'Santa Catarina', -27.1342000, -52.6566000, 'active', '2026-01-31 19:10:51', '2026-01-31 19:10:51'),
(1242, 'AIF', 'SBAS', 'Assis Airport', NULL, 'BR', 'Sao Paulo', -22.6400000, -50.4531000, 'active', '2026-01-31 19:10:51', '2026-01-31 19:10:51'),
(1243, 'AQA', 'SBAQ', 'Araraquara Airport', NULL, 'BR', 'Sao Paulo', -21.8120000, -48.1330000, 'active', '2026-01-31 19:10:52', '2026-01-31 19:10:52'),
(1244, 'ARU', 'SBAU', 'Aracatuba Airport', NULL, 'BR', 'Sao Paulo', -21.1413000, -50.4247000, 'active', '2026-01-31 19:10:52', '2026-01-31 19:10:52'),
(1245, 'BAT', 'SBBT', 'Chafei Amsei Airport', NULL, 'BR', 'Sao Paulo', -20.5845000, -48.5941000, 'active', '2026-01-31 19:10:52', '2026-01-31 19:10:52'),
(1246, 'BAU', 'SBBU', 'Bauru Airport', NULL, 'BR', 'Sao Paulo', -22.3436000, -49.0539000, 'active', '2026-01-31 19:10:53', '2026-01-31 19:10:53'),
(1247, 'BJP', 'SBBP', 'Arthur Siqueira-Braganca Paulista State Airport', NULL, 'BR', 'Sao Paulo', -22.9792000, -46.5375000, 'active', '2026-01-31 19:10:53', '2026-01-31 19:10:53'),
(1248, 'CGH', 'SBSP', 'Sao Paulo Congonhas Airport', NULL, 'BR', 'Sao Paulo', -23.6282000, -46.6572000, 'active', '2026-01-31 19:10:53', '2026-01-31 19:10:53'),
(1249, 'CPQ', 'SDAM', 'Campo dos Amarais Airport', NULL, 'BR', 'Sao Paulo', -22.8592000, -47.1081000, 'active', '2026-01-31 19:10:54', '2026-01-31 19:10:54'),
(1250, 'FRC', 'SIMK', 'Franca Airport (Ten. Lund Presotto-Franca State Airport)', NULL, 'BR', 'Sao Paulo', -20.5922000, -47.3829000, 'active', '2026-01-31 19:10:54', '2026-01-31 19:10:54'),
(1251, 'GUJ', 'SBGW', 'Guaratingueta Airport', NULL, 'BR', 'Sao Paulo', -22.7916000, -45.2048000, 'active', '2026-01-31 19:10:54', '2026-01-31 19:10:54'),
(1252, 'GRU', 'SBGR', 'Guarulhos International Airport', NULL, 'BR', 'Sao Paulo', -23.4322000, -46.4692000, 'active', '2026-01-31 19:10:55', '2026-01-31 19:10:55'),
(1253, 'JLS', 'SDJL', 'Jales Airport', NULL, 'BR', 'Sao Paulo', -20.2930000, -50.5464000, 'active', '2026-01-31 19:10:55', '2026-01-31 19:10:55'),
(1254, 'JTC', 'SBAE', 'Moussa Nakhl Tobias-Bauru/Arealva State Airport', NULL, 'BR', 'Sao Paulo', -22.1669000, -49.0503000, 'active', '2026-01-31 19:10:55', '2026-01-31 19:10:55'),
(1255, 'LIP', 'SBLN', 'Lins Airport', NULL, 'BR', 'Sao Paulo', -21.6640000, -49.7305000, 'active', '2026-01-31 19:10:56', '2026-01-31 19:10:56'),
(1256, 'MII', 'SBML', 'Frank Miloye Milenkowichi-Marilia State Airport', NULL, 'BR', 'Sao Paulo', -22.1969000, -49.9264000, 'active', '2026-01-31 19:10:56', '2026-01-31 19:10:56'),
(1257, 'OUS', 'SDOU', 'Jornalista Benedito Pimentel-Ourinhos State Airport', NULL, 'BR', 'Sao Paulo', -22.9665000, -49.9133000, 'active', '2026-01-31 19:10:56', '2026-01-31 19:10:56'),
(1258, 'PPB', 'SBDN', 'Presidente Prudente Airport', NULL, 'BR', 'Sao Paulo', -22.1751000, -51.4246000, 'active', '2026-01-31 19:10:57', '2026-01-31 19:10:57'),
(1259, 'QSC', 'SDSC', 'Mario Pereira Lopes Airport', NULL, 'BR', 'Sao Paulo', -21.8754000, -47.9037000, 'active', '2026-01-31 19:10:57', '2026-01-31 19:10:57'),
(1260, 'RAO', 'SBRP', 'Leite Lopes Airport', NULL, 'BR', 'Sao Paulo', -21.1364000, -47.7767000, 'active', '2026-01-31 19:10:57', '2026-01-31 19:10:57'),
(1261, 'SFV', NULL, 'Santa Fe do Sul Airport', NULL, 'BR', 'Sao Paulo', -20.1830000, -50.9170000, 'active', '2026-01-31 19:10:58', '2026-01-31 19:10:58'),
(1262, 'SJK', 'SBSJ', 'Professor Urbano Ernesto Stumpf International Airport', NULL, 'BR', 'Sao Paulo', -23.2292000, -45.8615000, 'active', '2026-01-31 19:10:58', '2026-01-31 19:10:58'),
(1263, 'SJP', 'SBSR', 'Prof. Eribelto Manoel Reino State Airport', NULL, 'BR', 'Sao Paulo', -20.8166000, -49.4065000, 'active', '2026-01-31 19:10:58', '2026-01-31 19:10:58'),
(1264, 'SOD', 'SDCO', 'Sorocaba Airport', NULL, 'BR', 'Sao Paulo', -23.4780000, -47.4900000, 'active', '2026-01-31 19:10:59', '2026-01-31 19:10:59'),
(1265, 'SSZ', 'SBST', 'Santos Air Force Base', NULL, 'BR', 'Sao Paulo', -23.9281000, -46.2997000, 'active', '2026-01-31 19:10:59', '2026-01-31 19:10:59'),
(1266, 'UBT', 'SDUB', 'Ubatuba Airport', NULL, 'BR', 'Sao Paulo', -23.4411000, -45.0756000, 'active', '2026-01-31 19:10:59', '2026-01-31 19:10:59'),
(1267, 'URB', 'SBUP', 'Castilho Airport (Urubupunga Airport)', NULL, 'BR', 'Sao Paulo', -20.7771000, -51.5648000, 'active', '2026-01-31 19:11:00', '2026-01-31 19:11:00'),
(1268, 'VCP', 'SBKP', 'Viracopos-Campinas International Airport', NULL, 'BR', 'Sao Paulo', -23.0081000, -47.1344000, 'active', '2026-01-31 19:11:00', '2026-01-31 19:11:00'),
(1269, 'VOT', 'SDVG', 'Votuporanga Airport (Domingos Pignatari Airport)', NULL, 'BR', 'Sao Paulo', -20.4632000, -50.0045000, 'active', '2026-01-31 19:11:00', '2026-01-31 19:11:00'),
(1270, 'AJU', 'SBAR', 'Santa Maria Airport (Sergipe)', NULL, 'BR', 'Sergipe', -10.9840000, -37.0703000, 'active', '2026-01-31 19:11:01', '2026-01-31 19:11:01'),
(1271, 'AAI', 'SWRA', 'Arraias Airport', NULL, 'BR', 'Tocantins', -13.0252000, -46.8841000, 'active', '2026-01-31 19:11:01', '2026-01-31 19:11:01'),
(1272, 'AUX', 'SWGN', 'Araguaina Airport', NULL, 'BR', 'Tocantins', -7.2278700, -48.2405000, 'active', '2026-01-31 19:11:01', '2026-01-31 19:11:01'),
(1273, 'DNO', 'SWDN', 'Dianopolis Airport', NULL, 'BR', 'Tocantins', -11.5954000, -46.8467000, 'active', '2026-01-31 19:11:02', '2026-01-31 19:11:02'),
(1274, 'GRP', 'SWGI', 'Gurupi Airport', NULL, 'BR', 'Tocantins', -11.7396000, -49.1322000, 'active', '2026-01-31 19:11:02', '2026-01-31 19:11:02'),
(1275, 'IDO', 'SWIY', 'Santa Isabel do Morro Airport', NULL, 'BR', 'Tocantins', -11.5723000, -50.6662000, 'active', '2026-01-31 19:11:02', '2026-01-31 19:11:02'),
(1276, 'NTM', NULL, 'Miracema do Tocantins Airport', NULL, 'BR', 'Tocantins', -9.5669000, -48.3919000, 'active', '2026-01-31 19:11:03', '2026-01-31 19:11:03'),
(1277, 'PMW', 'SBPJ', 'Palmas-Brigadeiro Lysias Rodrigues Airport', NULL, 'BR', 'Tocantins', -10.2915000, -48.3570000, 'active', '2026-01-31 19:11:03', '2026-01-31 19:11:03'),
(1278, 'PNB', 'SBPN', 'Porto Nacional Airport', NULL, 'BR', 'Tocantins', -10.7194000, -48.3997000, 'active', '2026-01-31 19:11:03', '2026-01-31 19:11:03'),
(1279, 'AXP', 'MYAP', 'Spring Point Airport', NULL, 'BS', 'Acklins', 22.4418000, -73.9709000, 'active', '2026-01-31 19:11:04', '2026-01-31 19:11:04'),
(1280, 'GHC', 'MYBG', 'Great Harbour Cay Airport', NULL, 'BS', 'Berry Islands', 25.7383000, -77.8401000, 'active', '2026-01-31 19:11:04', '2026-01-31 19:11:04'),
(1281, 'BIM', 'MYBS', 'South Bimini Airport', NULL, 'BS', 'Bimini', 25.6999000, -79.2647000, 'active', '2026-01-31 19:11:04', '2026-01-31 19:11:04'),
(1282, 'NSB', NULL, 'North Seaplane Base', NULL, 'BS', 'Bimini', 25.7670000, -79.2500000, 'active', '2026-01-31 19:11:05', '2026-01-31 19:11:05'),
(1283, 'TBI', 'MYCB', 'New Bight Airport', NULL, 'BS', 'Cat Island', 24.3153000, -75.4523000, 'active', '2026-01-31 19:11:05', '2026-01-31 19:11:05'),
(1284, 'ASD', 'MYAF', 'Andros Town International Airport', NULL, 'BS', 'Central Andros', 24.6979000, -77.7956000, 'active', '2026-01-31 19:11:05', '2026-01-31 19:11:05'),
(1285, 'CCZ', 'MYBC', 'Chub Cay International Airport', NULL, 'BS', 'Central Andros', 25.4171000, -77.8809000, 'active', '2026-01-31 19:11:06', '2026-01-31 19:11:06'),
(1286, 'MAY', 'MYAB', 'Clarence A. Bain Airport', NULL, 'BS', 'Central Andros', 24.2877000, -77.6846000, 'active', '2026-01-31 19:11:06', '2026-01-31 19:11:06'),
(1287, 'SAQ', 'MYAN', 'San Andros Airport', NULL, 'BS', 'Central Andros', 25.0538000, -78.0490000, 'active', '2026-01-31 19:11:06', '2026-01-31 19:11:06'),
(1288, 'CXY', 'MYCC', 'Cat Cay Airport', NULL, 'BS', 'City of Freeport', 25.5546000, -79.2752000, 'active', '2026-01-31 19:11:07', '2026-01-31 19:11:07'),
(1289, 'WKR', 'MYAW', 'Walker\'s Cay Airport', NULL, 'BS', 'City of Freeport', 27.2667000, -78.3997000, 'active', '2026-01-31 19:11:07', '2026-01-31 19:11:07');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(1290, 'FPO', 'MYGF', 'Grand Bahama International Airport', NULL, 'BS', 'East Grand Bahama', 26.5587000, -78.6956000, 'active', '2026-01-31 19:11:07', '2026-01-31 19:11:07'),
(1291, 'GGT', 'MYEF', 'Exuma International Airport', NULL, 'BS', 'Exuma', 23.5626000, -75.8780000, 'active', '2026-01-31 19:11:08', '2026-01-31 19:11:08'),
(1292, 'NMC', 'MYEN', 'Norman\'s Cay Airport', NULL, 'BS', 'Exuma', 24.5943000, -76.8202000, 'active', '2026-01-31 19:11:08', '2026-01-31 19:11:08'),
(1293, 'TYM', 'MYES', 'Staniel Cay Airport', NULL, 'BS', 'Exuma', 24.1691000, -76.4391000, 'active', '2026-01-31 19:11:08', '2026-01-31 19:11:08'),
(1294, 'ELH', 'MYEH', 'North Eleuthera Airport', NULL, 'BS', 'Harbour Island', 25.4749000, -76.6835000, 'active', '2026-01-31 19:11:09', '2026-01-31 19:11:09'),
(1295, 'MHH', 'MYAM', 'Marsh Harbour Airport', NULL, 'BS', 'Hope Town', 26.5114000, -77.0835000, 'active', '2026-01-31 19:11:09', '2026-01-31 19:11:09'),
(1296, 'TCB', 'MYAT', 'Treasure Cay Airport', NULL, 'BS', 'Hope Town', 26.7453000, -77.3913000, 'active', '2026-01-31 19:11:09', '2026-01-31 19:11:09'),
(1297, 'IGA', 'MYIG', 'Inagua Airport (Matthew Town Airport)', NULL, 'BS', 'Inagua', 20.9750000, -73.6669000, 'active', '2026-01-31 19:11:10', '2026-01-31 19:11:10'),
(1298, 'CRI', 'MYCI', 'Colonel Hill Airport (Crooked Island Airport)', NULL, 'BS', 'Long Island', 22.7456000, -74.1824000, 'active', '2026-01-31 19:11:10', '2026-01-31 19:11:10'),
(1299, 'DCT', 'MYRD', 'Duncan Town Airport', NULL, 'BS', 'Long Island', 22.1818000, -75.7295000, 'active', '2026-01-31 19:11:10', '2026-01-31 19:11:10'),
(1300, 'LGI', 'MYLD', 'Deadman\'s Cay Airport', NULL, 'BS', 'Long Island', 23.1790000, -75.0936000, 'active', '2026-01-31 19:11:11', '2026-01-31 19:11:11'),
(1301, 'PWN', 'MYCP', 'Pitts Town Airport', NULL, 'BS', 'Long Island', 22.8297000, -74.3461000, 'active', '2026-01-31 19:11:11', '2026-01-31 19:11:11'),
(1302, 'SML', 'MYLS', 'Stella Maris Airport', NULL, 'BS', 'Long Island', 23.5823000, -75.2686000, 'active', '2026-01-31 19:11:11', '2026-01-31 19:11:11'),
(1303, 'MYG', 'MYMM', 'Mayaguana Airport (Abraham\'s Bay Airport)', NULL, 'BS', 'Mayaguana', 22.3795000, -73.0135000, 'active', '2026-01-31 19:11:12', '2026-01-31 19:11:12'),
(1304, 'NAS', 'MYNN', 'Lynden Pindling International Airport', NULL, 'BS', 'New Providence', 25.0390000, -77.4662000, 'active', '2026-01-31 19:11:12', '2026-01-31 19:11:12'),
(1305, 'RCY', 'MYRP', 'Port Nelson Airport', NULL, 'BS', 'Rum Cay', 23.6844000, -74.8362000, 'active', '2026-01-31 19:11:12', '2026-01-31 19:11:12'),
(1306, 'ZSA', 'MYSM', 'San Salvador Airport (Cockburn Town Airport)', NULL, 'BS', 'San Salvador', 24.0633000, -74.5240000, 'active', '2026-01-31 19:11:13', '2026-01-31 19:11:13'),
(1307, 'TZN', 'MYAK', 'South Andros Airport', NULL, 'BS', 'South Andros', 24.1589000, -77.5897000, 'active', '2026-01-31 19:11:13', '2026-01-31 19:11:13'),
(1308, 'ATC', 'MYCA', 'Arthur\'s Town Airport', NULL, 'BS', 'South Eleuthera', 24.6294000, -75.6738000, 'active', '2026-01-31 19:11:13', '2026-01-31 19:11:13'),
(1309, 'GHB', 'MYEM', 'Governor\'s Harbour Airport', NULL, 'BS', 'South Eleuthera', 25.2847000, -76.3310000, 'active', '2026-01-31 19:11:14', '2026-01-31 19:11:14'),
(1310, 'RSD', 'MYER', 'Rock Sound International Airport', NULL, 'BS', 'South Eleuthera', 24.8951000, -76.1769000, 'active', '2026-01-31 19:11:14', '2026-01-31 19:11:14'),
(1311, 'WTD', 'MYGW', 'West End Airport', NULL, 'BS', 'West Grand Bahama', 26.6853000, -78.9750000, 'active', '2026-01-31 19:11:14', '2026-01-31 19:11:14'),
(1312, 'BUT', 'VQBT', 'Bathpalathang Airport', NULL, 'BT', 'Bumthang', 27.5622000, 90.7471000, 'active', '2026-01-31 19:11:15', '2026-01-31 19:11:15'),
(1313, 'PBH', 'VQPR', 'Paro International Airport', NULL, 'BT', 'Paro', 27.4032000, 89.4246000, 'active', '2026-01-31 19:11:15', '2026-01-31 19:11:15'),
(1314, 'GLU', 'VQGP', 'Gelephu Airport', NULL, 'BT', 'Sarpang', 26.8846000, 90.4641000, 'active', '2026-01-31 19:11:15', '2026-01-31 19:11:15'),
(1315, 'YON', 'VQTY', 'Yongphulla Airport (Yonphula Airport)', NULL, 'BT', 'Trashigang', 27.2564000, 91.5145000, 'active', '2026-01-31 19:11:16', '2026-01-31 19:11:16'),
(1316, 'ORP', 'FBOR', 'Orapa Airport', NULL, 'BW', 'Central', -21.2667000, 25.3167000, 'active', '2026-01-31 19:11:16', '2026-01-31 19:11:16'),
(1317, 'PKW', 'FBSP', 'Selebi-Phikwe Airport', NULL, 'BW', 'Central', -22.0583000, 27.8288000, 'active', '2026-01-31 19:11:16', '2026-01-31 19:11:16'),
(1318, 'SXN', 'FBSN', 'Sua Pan Airport', NULL, 'BW', 'Central', -20.5534000, 26.1158000, 'active', '2026-01-31 19:11:17', '2026-01-31 19:11:17'),
(1319, 'TLD', 'FBTL', 'Tuli Lodge Airport', NULL, 'BW', 'Central', -22.1892000, 29.1269000, 'active', '2026-01-31 19:11:17', '2026-01-31 19:11:17'),
(1320, 'BBK', 'FBKE', 'Kasane Airport', NULL, 'BW', 'Chobe', -17.8329000, 25.1624000, 'active', '2026-01-31 19:11:17', '2026-01-31 19:11:17'),
(1321, 'GNZ', 'FBGZ', 'Ghanzi Airport', NULL, 'BW', 'Ghanzi', -21.6925000, 21.6581000, 'active', '2026-01-31 19:11:18', '2026-01-31 19:11:18'),
(1322, 'HUK', NULL, 'Hukuntsi Airport', NULL, 'BW', 'Kgalagadi', -23.9897000, 21.7581000, 'active', '2026-01-31 19:11:18', '2026-01-31 19:11:18'),
(1323, 'TBY', 'FBTS', 'Tshabong Airport', NULL, 'BW', 'Kgalagadi', -26.0333000, 22.4000000, 'active', '2026-01-31 19:11:18', '2026-01-31 19:11:18'),
(1324, 'FRW', 'FBFT', 'Francistown Airport', NULL, 'BW', 'North East', -21.1596000, 27.4745000, 'active', '2026-01-31 19:11:19', '2026-01-31 19:11:19'),
(1325, 'KHW', 'FBKR', 'Khwai River Airport', NULL, 'BW', 'North West', -19.1500000, 23.7830000, 'active', '2026-01-31 19:11:19', '2026-01-31 19:11:19'),
(1326, 'MUB', 'FBMN', 'Maun Airport', NULL, 'BW', 'North West', -19.9726000, 23.4311000, 'active', '2026-01-31 19:11:19', '2026-01-31 19:11:19'),
(1327, 'SVT', 'FBSV', 'Savuti Airport', NULL, 'BW', 'North West', -18.5206000, 24.0767000, 'active', '2026-01-31 19:11:20', '2026-01-31 19:11:20'),
(1328, 'SWX', 'FBSW', 'Shakawe Airport', NULL, 'BW', 'North West', -18.3739000, 21.8326000, 'active', '2026-01-31 19:11:20', '2026-01-31 19:11:20'),
(1329, 'GBE', 'FBSK', 'Sir Seretse Khama International Airport', NULL, 'BW', 'South East', -24.5552000, 25.9182000, 'active', '2026-01-31 19:11:20', '2026-01-31 19:11:20'),
(1330, 'LOQ', 'FBLO', 'Lobatse Airport', NULL, 'BW', 'South East', -25.1981000, 25.7139000, 'active', '2026-01-31 19:11:21', '2026-01-31 19:11:21'),
(1331, 'JWA', 'FBJW', 'Jwaneng Airport', NULL, 'BW', 'Southern', -24.6023000, 24.6910000, 'active', '2026-01-31 19:11:21', '2026-01-31 19:11:21'),
(1332, 'BQT', 'UMBB', 'Brest Airport', NULL, 'BY', 'Brestskaya voblasts\'', 52.1083000, 23.8981000, 'active', '2026-01-31 19:11:21', '2026-01-31 19:11:21'),
(1333, 'GME', 'UMGG', 'Gomel Airport', NULL, 'BY', 'Homyel\'skaya voblasts\'', 52.5270000, 31.0167000, 'active', '2026-01-31 19:11:22', '2026-01-31 19:11:22'),
(1334, 'GNA', 'UMMG', 'Grodno Airport', NULL, 'BY', 'Hrodzenskaya voblasts\'', 53.6020000, 24.0538000, 'active', '2026-01-31 19:11:22', '2026-01-31 19:11:22'),
(1335, 'MVQ', 'UMOO', 'Mogilev Airport', NULL, 'BY', 'Mahilyowskaya voblasts\'', 53.9549000, 30.0951000, 'active', '2026-01-31 19:11:22', '2026-01-31 19:11:22'),
(1336, 'MHP', 'UMMM', 'Minsk-1 Airport', NULL, 'BY', 'Minskaya voblasts\'', 53.8645000, 27.5397000, 'active', '2026-01-31 19:11:23', '2026-01-31 19:11:23'),
(1337, 'MSQ', 'UMMS', 'Minsk National Airport', NULL, 'BY', 'Minskaya voblasts\'', 53.8825000, 28.0307000, 'active', '2026-01-31 19:11:23', '2026-01-31 19:11:23'),
(1338, 'VTB', 'UMII', 'Vitebsk Vostochny Airport', NULL, 'BY', 'Vitsyebskaya voblasts\'', 55.1265000, 30.3496000, 'active', '2026-01-31 19:11:23', '2026-01-31 19:11:23'),
(1339, 'BZE', 'MZBZ', 'Philip S. W. Goldson International Airport', NULL, 'BZ', 'Belize', 17.5391000, -88.3082000, 'active', '2026-01-31 19:11:24', '2026-01-31 19:11:24'),
(1340, 'CUK', NULL, 'Caye Caulker Airport', NULL, 'BZ', 'Belize', 17.7347000, -88.0325000, 'active', '2026-01-31 19:11:24', '2026-01-31 19:11:24'),
(1341, 'CYC', NULL, 'Caye Chapel Airport', NULL, 'BZ', 'Belize', 17.7008000, -88.0411000, 'active', '2026-01-31 19:11:24', '2026-01-31 19:11:24'),
(1342, 'SPR', NULL, 'John Greif II Airport', NULL, 'BZ', 'Belize', 17.9139000, -87.9711000, 'active', '2026-01-31 19:11:25', '2026-01-31 19:11:25'),
(1343, 'TZA', NULL, 'Belize City Municipal Airport', NULL, 'BZ', 'Belize', 17.5164000, -88.1944000, 'active', '2026-01-31 19:11:25', '2026-01-31 19:11:25'),
(1344, 'BCV', NULL, 'Hector Silva Airstrip', NULL, 'BZ', 'Cayo', 17.2696000, -88.7765000, 'active', '2026-01-31 19:11:25', '2026-01-31 19:11:25'),
(1345, 'CYD', NULL, 'San Ignacio Town Airstrip', NULL, 'BZ', 'Cayo', 17.1049000, -89.1011000, 'active', '2026-01-31 19:11:26', '2026-01-31 19:11:26'),
(1346, 'MZE', NULL, 'Manatee Airport', NULL, 'BZ', 'Cayo', 17.2785000, -89.0238000, 'active', '2026-01-31 19:11:26', '2026-01-31 19:11:26'),
(1347, 'SQS', NULL, 'Matthew Spain Airport', NULL, 'BZ', 'Cayo', 17.1859000, -89.0098000, 'active', '2026-01-31 19:11:26', '2026-01-31 19:11:26'),
(1348, 'CZH', NULL, 'Corozal Airport', NULL, 'BZ', 'Corozal', 18.3822000, -88.4119000, 'active', '2026-01-31 19:11:27', '2026-01-31 19:11:27'),
(1349, 'SJX', NULL, 'Sarteneja Airport', NULL, 'BZ', 'Corozal', 18.3561000, -88.1308000, 'active', '2026-01-31 19:11:27', '2026-01-31 19:11:27'),
(1350, 'ORZ', NULL, 'Orange Walk Airport', NULL, 'BZ', 'Orange Walk', 18.0468000, -88.5839000, 'active', '2026-01-31 19:11:27', '2026-01-31 19:11:27'),
(1351, 'BGK', NULL, 'Big Creek Airport', NULL, 'BZ', 'Stann Creek', 16.5194000, -88.4079000, 'active', '2026-01-31 19:11:28', '2026-01-31 19:11:28'),
(1352, 'DGA', NULL, 'Dangriga Airport', NULL, 'BZ', 'Stann Creek', 16.9825000, -88.2310000, 'active', '2026-01-31 19:11:28', '2026-01-31 19:11:28'),
(1353, 'INB', NULL, 'Independence Airport (Belize)', NULL, 'BZ', 'Stann Creek', 16.5345000, -88.4413000, 'active', '2026-01-31 19:11:28', '2026-01-31 19:11:28'),
(1354, 'MDB', NULL, 'Melinda Airport', NULL, 'BZ', 'Stann Creek', 17.0043000, -88.3042000, 'active', '2026-01-31 19:11:29', '2026-01-31 19:11:29'),
(1355, 'PLJ', 'MZPL', 'Placencia Airport', NULL, 'BZ', 'Stann Creek', 16.5370000, -88.3615000, 'active', '2026-01-31 19:11:29', '2026-01-31 19:11:29'),
(1356, 'SVK', NULL, 'Silver Creek Airport', NULL, 'BZ', 'Stann Creek', 16.7253000, -88.3400000, 'active', '2026-01-31 19:11:29', '2026-01-31 19:11:29'),
(1357, 'PND', NULL, 'Punta Gorda Airport', NULL, 'BZ', 'Toledo', 16.1024000, -88.8083000, 'active', '2026-01-31 19:11:30', '2026-01-31 19:11:30'),
(1358, 'HZP', 'CYNR', 'Fort MacKay/Horizon Airport', NULL, 'CA', 'Alberta', 57.3817000, -111.7010000, 'active', '2026-01-31 19:11:30', '2026-01-31 19:11:30'),
(1359, 'JHL', NULL, 'Fort MacKay/Albian Aerodrome', NULL, 'CA', 'Alberta', 57.2239000, -111.4190000, 'active', '2026-01-31 19:11:30', '2026-01-31 19:11:30'),
(1360, 'NML', NULL, 'Fort McMurray/Mildred Lake Airport', NULL, 'CA', 'Alberta', 57.0556000, -111.5740000, 'active', '2026-01-31 19:11:31', '2026-01-31 19:11:31'),
(1361, 'TIL', NULL, 'Cheadle Airport', NULL, 'CA', 'Alberta', 51.0575000, -113.6240000, 'active', '2026-01-31 19:11:31', '2026-01-31 19:11:31'),
(1362, 'WPC', 'CZPC', 'Pincher Creek Airport', NULL, 'CA', 'Alberta', 49.5206000, -113.9970000, 'active', '2026-01-31 19:11:31', '2026-01-31 19:11:31'),
(1363, 'YBA', 'CYBA', 'Banff Airport', NULL, 'CA', 'Alberta', 51.2073000, -115.5420000, 'active', '2026-01-31 19:11:32', '2026-01-31 19:11:32'),
(1364, 'YBY', 'CYBF', 'Bonnyville Airport', NULL, 'CA', 'Alberta', 54.3042000, -110.7440000, 'active', '2026-01-31 19:11:32', '2026-01-31 19:11:32'),
(1365, 'YCT', 'CYCT', 'Coronation Airport', NULL, 'CA', 'Alberta', 52.0750000, -111.4450000, 'active', '2026-01-31 19:11:32', '2026-01-31 19:11:32'),
(1366, 'YDC', NULL, 'Drayton Valley Industrial Airport', NULL, 'CA', 'Alberta', 53.2658000, -114.9600000, 'active', '2026-01-31 19:11:33', '2026-01-31 19:11:33'),
(1367, 'YEG', 'CYEG', 'Edmonton International Airport', NULL, 'CA', 'Alberta', 53.3100000, -113.5790000, 'active', '2026-01-31 19:11:33', '2026-01-31 19:11:33'),
(1368, 'YET', 'CYET', 'Edson Airport', NULL, 'CA', 'Alberta', 53.5789000, -116.4650000, 'active', '2026-01-31 19:11:33', '2026-01-31 19:11:33'),
(1369, 'YFI', NULL, 'Fort MacKay/Firebag Aerodrome', NULL, 'CA', 'Alberta', 57.2758000, -110.9770000, 'active', '2026-01-31 19:11:34', '2026-01-31 19:11:34'),
(1370, 'YGC', NULL, 'Grande Cache Airport', NULL, 'CA', 'Alberta', 53.9169000, -118.8740000, 'active', '2026-01-31 19:11:34', '2026-01-31 19:11:34'),
(1371, 'YJA', 'CYJA', 'Jasper Airport', NULL, 'CA', 'Alberta', 52.9967000, -118.0590000, 'active', '2026-01-31 19:11:34', '2026-01-31 19:11:34'),
(1372, 'YJP', NULL, 'Hinton/Jasper-Hinton Airport', NULL, 'CA', 'Alberta', 53.3192000, -117.7530000, 'active', '2026-01-31 19:11:35', '2026-01-31 19:11:35'),
(1373, 'YLB', 'CYLB', 'Lac La Biche Airport', NULL, 'CA', 'Alberta', 54.7703000, -112.0320000, 'active', '2026-01-31 19:11:35', '2026-01-31 19:11:35'),
(1374, 'YLL', 'CYLL', 'Lloydminster Airport', NULL, 'CA', 'Alberta', 53.3092000, -110.0730000, 'active', '2026-01-31 19:11:35', '2026-01-31 19:11:35'),
(1375, 'YMM', 'CYMM', 'Fort McMurray International Airport', NULL, 'CA', 'Alberta', 56.6533000, -111.2220000, 'active', '2026-01-31 19:11:36', '2026-01-31 19:11:36'),
(1376, 'YOD', 'CYOD', 'CFB Cold Lake (R.W. McNair Airport)', NULL, 'CA', 'Alberta', 54.4050000, -110.2790000, 'active', '2026-01-31 19:11:36', '2026-01-31 19:11:36'),
(1377, 'YOE', NULL, 'Donnelly Airport', NULL, 'CA', 'Alberta', 55.7094000, -117.0940000, 'active', '2026-01-31 19:11:36', '2026-01-31 19:11:36'),
(1378, 'YOJ', 'CYOJ', 'High Level Airport', NULL, 'CA', 'Alberta', 58.6214000, -117.1650000, 'active', '2026-01-31 19:11:37', '2026-01-31 19:11:37'),
(1379, 'YOP', 'CYOP', 'Rainbow Lake Airport', NULL, 'CA', 'Alberta', 58.4914000, -119.4080000, 'active', '2026-01-31 19:11:37', '2026-01-31 19:11:37'),
(1380, 'YPE', 'CYPE', 'Peace River Airport', NULL, 'CA', 'Alberta', 56.2269000, -117.4470000, 'active', '2026-01-31 19:11:37', '2026-01-31 19:11:37'),
(1381, 'YPY', 'CYPY', 'Fort Chipewyan Airport', NULL, 'CA', 'Alberta', 58.7672000, -111.1170000, 'active', '2026-01-31 19:11:38', '2026-01-31 19:11:38'),
(1382, 'YQF', 'CYQF', 'Red Deer Regional Airport', NULL, 'CA', 'Alberta', 52.1822000, -113.8940000, 'active', '2026-01-31 19:11:38', '2026-01-31 19:11:38'),
(1383, 'YQL', 'CYQL', 'Lethbridge Airport', NULL, 'CA', 'Alberta', 49.6303000, -112.8000000, 'active', '2026-01-31 19:11:38', '2026-01-31 19:11:38'),
(1384, 'YQU', 'CYQU', 'Grande Prairie Airport', NULL, 'CA', 'Alberta', 55.1797000, -118.8850000, 'active', '2026-01-31 19:11:39', '2026-01-31 19:11:39'),
(1385, 'YRM', 'CYRM', 'Rocky Mountain House Airport', NULL, 'CA', 'Alberta', 52.4297000, -114.9040000, 'active', '2026-01-31 19:11:39', '2026-01-31 19:11:39'),
(1386, 'YSD', 'CYSD', 'CFB Suffield', NULL, 'CA', 'Alberta', 50.2667000, -111.1830000, 'active', '2026-01-31 19:11:39', '2026-01-31 19:11:39'),
(1387, 'YVG', 'CYVG', 'Vermilion Airport', NULL, 'CA', 'Alberta', 53.3558000, -110.8240000, 'active', '2026-01-31 19:11:40', '2026-01-31 19:11:40'),
(1388, 'YXH', 'CYXH', 'Medicine Hat Airport', NULL, 'CA', 'Alberta', 50.0189000, -110.7210000, 'active', '2026-01-31 19:11:40', '2026-01-31 19:11:40'),
(1389, 'YYC', 'CYYC', 'Calgary International Airport', NULL, 'CA', 'Alberta', 51.1139000, -114.0200000, 'active', '2026-01-31 19:11:40', '2026-01-31 19:11:40'),
(1390, 'YYM', 'CYYM', 'Cowley Airport', NULL, 'CA', 'Alberta', 49.6364000, -114.0940000, 'active', '2026-01-31 19:11:41', '2026-01-31 19:11:41'),
(1391, 'YZH', 'CYZH', 'Slave Lake Airport', NULL, 'CA', 'Alberta', 55.2931000, -114.7770000, 'active', '2026-01-31 19:11:41', '2026-01-31 19:11:41'),
(1392, 'YZU', 'CYZU', 'Whitecourt Airport', NULL, 'CA', 'Alberta', 54.1439000, -115.7870000, 'active', '2026-01-31 19:11:41', '2026-01-31 19:11:41'),
(1393, 'ZFW', NULL, 'Fairview Airport', NULL, 'CA', 'Alberta', 56.0814000, -118.4350000, 'active', '2026-01-31 19:11:42', '2026-01-31 19:11:42'),
(1394, 'ZHP', 'CZHP', 'High Prairie Airport', NULL, 'CA', 'Alberta', 55.3936000, -116.4750000, 'active', '2026-01-31 19:11:42', '2026-01-31 19:11:42'),
(1395, 'CFQ', NULL, 'Creston Aerodrome', NULL, 'CA', 'British Columbia', 49.0369000, -116.4980000, 'active', '2026-01-31 19:11:42', '2026-01-31 19:11:42'),
(1396, 'CJH', NULL, 'Chilko Lake (Tsylos Park Lodge) Aerodrome', NULL, 'CA', 'British Columbia', 51.6261000, -124.1420000, 'active', '2026-01-31 19:11:43', '2026-01-31 19:11:43'),
(1397, 'CXH', 'CYHC', 'Vancouver Harbour Flight Centre (Coal Harbour Seaplane Base)', NULL, 'CA', 'British Columbia', 49.2944000, -123.1110000, 'active', '2026-01-31 19:11:43', '2026-01-31 19:11:43'),
(1398, 'DGF', NULL, 'Douglas Lake Airport', NULL, 'CA', 'British Columbia', 50.1655000, -120.1710000, 'active', '2026-01-31 19:11:43', '2026-01-31 19:11:43'),
(1399, 'DUQ', NULL, 'Duncan Airport', NULL, 'CA', 'British Columbia', 48.7545000, -123.7100000, 'active', '2026-01-31 19:11:44', '2026-01-31 19:11:44'),
(1400, 'QBC', 'CYBD', 'Bella Coola Airport', NULL, 'CA', 'British Columbia', 52.3875000, -126.5960000, 'active', '2026-01-31 19:11:44', '2026-01-31 19:11:44'),
(1401, 'SYF', NULL, 'Silva Bay Seaplane Base', NULL, 'CA', 'British Columbia', 49.1500000, -123.6960000, 'active', '2026-01-31 19:11:44', '2026-01-31 19:11:44'),
(1402, 'TUX', NULL, 'Tumbler Ridge Airport', NULL, 'CA', 'British Columbia', 55.0250000, -120.9350000, 'active', '2026-01-31 19:11:45', '2026-01-31 19:11:45'),
(1403, 'WPL', NULL, 'Powell Lake Water Aerodrome', NULL, 'CA', 'British Columbia', 49.8833000, -124.5330000, 'active', '2026-01-31 19:11:45', '2026-01-31 19:11:45'),
(1404, 'XBB', NULL, 'Blubber Bay Seaplane Base', NULL, 'CA', 'British Columbia', 49.7940000, -124.6210000, 'active', '2026-01-31 19:11:45', '2026-01-31 19:11:45'),
(1405, 'XQU', NULL, 'Qualicum Beach Airport', NULL, 'CA', 'British Columbia', 49.3372000, -124.3940000, 'active', '2026-01-31 19:11:46', '2026-01-31 19:11:46'),
(1406, 'YAA', NULL, 'Anahim Lake Airport', NULL, 'CA', 'British Columbia', 52.4525000, -125.3030000, 'active', '2026-01-31 19:11:46', '2026-01-31 19:11:46'),
(1407, 'YAJ', NULL, 'Lyall Harbour Seaplane Base', NULL, 'CA', 'British Columbia', 48.7952000, -123.1820000, 'active', '2026-01-31 19:11:46', '2026-01-31 19:11:46'),
(1408, 'YAL', 'CYAL', 'Alert Bay Airport', NULL, 'CA', 'British Columbia', 50.5822000, -126.9160000, 'active', '2026-01-31 19:11:47', '2026-01-31 19:11:47'),
(1409, 'YAQ', NULL, 'Maple Bay Seaplane Base', NULL, 'CA', 'British Columbia', 48.8167000, -123.6080000, 'active', '2026-01-31 19:11:47', '2026-01-31 19:11:47'),
(1410, 'YAV', NULL, 'Mayne Island Water Aerodrome (Miner\'s Bay Seaplane Base)', NULL, 'CA', 'British Columbia', 48.8667000, -123.3000000, 'active', '2026-01-31 19:11:47', '2026-01-31 19:11:47'),
(1411, 'YAZ', 'CYAZ', 'Tofino/Long Beach Airport', NULL, 'CA', 'British Columbia', 49.0798000, -125.7760000, 'active', '2026-01-31 19:11:48', '2026-01-31 19:11:48'),
(1412, 'YBF', NULL, 'Bamfield Water Aerodrome', NULL, 'CA', 'British Columbia', 48.8333000, -125.1330000, 'active', '2026-01-31 19:11:48', '2026-01-31 19:11:48'),
(1413, 'YBH', 'CYBH', 'Bull Harbour Waterdrome', NULL, 'CA', 'British Columbia', 50.9179000, -127.9370000, 'active', '2026-01-31 19:11:48', '2026-01-31 19:11:48'),
(1414, 'YBL', 'CYBL', 'Campbell River Airport', NULL, 'CA', 'British Columbia', 49.9508000, -125.2710000, 'active', '2026-01-31 19:11:49', '2026-01-31 19:11:49'),
(1415, 'YBO', NULL, 'Bob Quinn Lake Airport', NULL, 'CA', 'British Columbia', 56.9667000, -130.2500000, 'active', '2026-01-31 19:11:49', '2026-01-31 19:11:49'),
(1416, 'YBQ', NULL, 'Telegraph Harbour Seaplane Base', NULL, 'CA', 'British Columbia', 48.9700000, -123.6640000, 'active', '2026-01-31 19:11:49', '2026-01-31 19:11:49'),
(1417, 'YBW', NULL, 'Bedwell Harbour Water Aerodrome', NULL, 'CA', 'British Columbia', 48.7500000, -123.2330000, 'active', '2026-01-31 19:11:50', '2026-01-31 19:11:50'),
(1418, 'YCA', NULL, 'Courtenay Airpark', NULL, 'CA', 'British Columbia', 49.6794000, -124.9820000, 'active', '2026-01-31 19:11:50', '2026-01-31 19:11:50'),
(1419, 'YCD', 'CYCD', 'Nanaimo Airport', NULL, 'CA', 'British Columbia', 49.0550000, -123.8700000, 'active', '2026-01-31 19:11:50', '2026-01-31 19:11:50'),
(1420, 'YCF', NULL, 'Cortes Island Aerodrome', NULL, 'CA', 'British Columbia', 50.0630000, -124.9300000, 'active', '2026-01-31 19:11:51', '2026-01-31 19:11:51'),
(1421, 'YCG', 'CYCG', 'West Kootenay Regional Airport (Castlegar Airport)', NULL, 'CA', 'British Columbia', 49.2964000, -117.6320000, 'active', '2026-01-31 19:11:51', '2026-01-31 19:11:51'),
(1422, 'YCQ', 'CYCQ', 'Chetwynd Airport', NULL, 'CA', 'British Columbia', 55.6872000, -121.6270000, 'active', '2026-01-31 19:11:51', '2026-01-31 19:11:51'),
(1423, 'YCW', 'CYCW', 'Chilliwack Airport', NULL, 'CA', 'British Columbia', 49.1528000, -121.9390000, 'active', '2026-01-31 19:11:52', '2026-01-31 19:11:52'),
(1424, 'YCZ', 'CYCZ', 'Fairmont Hot Springs Airport', NULL, 'CA', 'British Columbia', 50.3303000, -115.8730000, 'active', '2026-01-31 19:11:52', '2026-01-31 19:11:52'),
(1425, 'YDL', 'CYDL', 'Dease Lake Airport', NULL, 'CA', 'British Columbia', 58.4222000, -130.0320000, 'active', '2026-01-31 19:11:52', '2026-01-31 19:11:52'),
(1426, 'YDQ', 'CYDQ', 'Dawson Creek Airport', NULL, 'CA', 'British Columbia', 55.7423000, -120.1830000, 'active', '2026-01-31 19:11:53', '2026-01-31 19:11:53'),
(1427, 'YDT', 'CZBB', 'Boundary Bay Airport', NULL, 'CA', 'British Columbia', 49.0742000, -123.0120000, 'active', '2026-01-31 19:11:53', '2026-01-31 19:11:53'),
(1428, 'YGB', 'CYGB', 'Texada/Gillies Bay Airport', NULL, 'CA', 'British Columbia', 49.6942000, -124.5180000, 'active', '2026-01-31 19:11:54', '2026-01-31 19:11:54'),
(1429, 'YGE', NULL, 'Gorge Harbour Seaplane Base', NULL, 'CA', 'British Columbia', 50.0994000, -125.0230000, 'active', '2026-01-31 19:11:54', '2026-01-31 19:11:54'),
(1430, 'YGG', NULL, 'Ganges Water Aerodrome', NULL, 'CA', 'British Columbia', 48.8545000, -123.4970000, 'active', '2026-01-31 19:11:54', '2026-01-31 19:11:54'),
(1431, 'YGN', NULL, 'Greenway Sound Seaplane Base', NULL, 'CA', 'British Columbia', 50.8390000, -126.7750000, 'active', '2026-01-31 19:11:55', '2026-01-31 19:11:55'),
(1432, 'YHC', NULL, 'Hakai Passage Water Aerodrome', NULL, 'CA', 'British Columbia', 51.7330000, -128.1170000, 'active', '2026-01-31 19:11:55', '2026-01-31 19:11:55'),
(1433, 'YHE', 'CYHE', 'Hope Aerodrome', NULL, 'CA', 'British Columbia', 49.3683000, -121.4980000, 'active', '2026-01-31 19:11:55', '2026-01-31 19:11:55'),
(1434, 'YHH', NULL, 'Campbell River Water Aerodrome', NULL, 'CA', 'British Columbia', 50.0500000, -125.2500000, 'active', '2026-01-31 19:11:56', '2026-01-31 19:11:56'),
(1435, 'YHS', NULL, 'Sechelt Aerodrome', NULL, 'CA', 'British Columbia', 49.4606000, -123.7190000, 'active', '2026-01-31 19:11:56', '2026-01-31 19:11:56'),
(1436, 'YIG', NULL, 'Big Bay Water Aerodrome', NULL, 'CA', 'British Columbia', 50.3923000, -125.1370000, 'active', '2026-01-31 19:11:56', '2026-01-31 19:11:56'),
(1437, 'YKA', 'CYKA', 'Kamloops Airport', NULL, 'CA', 'British Columbia', 50.7022000, -120.4440000, 'active', '2026-01-31 19:11:57', '2026-01-31 19:11:57'),
(1438, 'YKK', NULL, 'Kitkatla Water Aerodrome', NULL, 'CA', 'British Columbia', 53.8000000, -130.4330000, 'active', '2026-01-31 19:11:57', '2026-01-31 19:11:57'),
(1439, 'YKT', NULL, 'Klemtu Water Aerodrome', NULL, 'CA', 'British Columbia', 52.6076000, -128.5220000, 'active', '2026-01-31 19:11:57', '2026-01-31 19:11:57'),
(1440, 'YLW', 'CYLW', 'Kelowna International Airport', NULL, 'CA', 'British Columbia', 49.9561000, -119.3780000, 'active', '2026-01-31 19:11:58', '2026-01-31 19:11:58'),
(1441, 'YLY', 'CYNJ', 'Langley Regional Airport', NULL, 'CA', 'British Columbia', 49.1008000, -122.6310000, 'active', '2026-01-31 19:11:58', '2026-01-31 19:11:58'),
(1442, 'YMB', NULL, 'Merritt Airport', NULL, 'CA', 'British Columbia', 50.1228000, -120.7470000, 'active', '2026-01-31 19:11:58', '2026-01-31 19:11:58'),
(1443, 'YMF', NULL, 'Montague Harbour Water Aerodrome', NULL, 'CA', 'British Columbia', 48.8170000, -123.2000000, 'active', '2026-01-31 19:11:59', '2026-01-31 19:11:59'),
(1444, 'YMP', NULL, 'Port McNeill Airport', NULL, 'CA', 'British Columbia', 50.5756000, -127.0290000, 'active', '2026-01-31 19:11:59', '2026-01-31 19:11:59'),
(1445, 'YMU', NULL, 'Mansons Landing Water Aerodrome', NULL, 'CA', 'British Columbia', 50.0667000, -124.9830000, 'active', '2026-01-31 19:11:59', '2026-01-31 19:11:59'),
(1446, 'YNH', 'CYNH', 'Hudson\'s Hope Airport', NULL, 'CA', 'British Columbia', 56.0356000, -121.9760000, 'active', '2026-01-31 19:12:00', '2026-01-31 19:12:00'),
(1447, 'YPB', NULL, 'Alberni Valley Regional Airport', NULL, 'CA', 'British Columbia', 49.3219000, -124.9310000, 'active', '2026-01-31 19:12:00', '2026-01-31 19:12:00'),
(1448, 'YPI', NULL, 'Port Simpson Water Aerodrome', NULL, 'CA', 'British Columbia', 54.5667000, -130.4330000, 'active', '2026-01-31 19:12:00', '2026-01-31 19:12:00'),
(1449, 'YPR', 'CYPR', 'Prince Rupert Airport', NULL, 'CA', 'British Columbia', 54.2861000, -130.4450000, 'active', '2026-01-31 19:12:01', '2026-01-31 19:12:01'),
(1450, 'YPT', NULL, 'Pender Harbour Water Aerodrome', NULL, 'CA', 'British Columbia', 49.6238000, -124.0250000, 'active', '2026-01-31 19:12:01', '2026-01-31 19:12:01'),
(1451, 'YPW', 'CYPW', 'Powell River Airport', NULL, 'CA', 'British Columbia', 49.8342000, -124.5000000, 'active', '2026-01-31 19:12:01', '2026-01-31 19:12:01'),
(1452, 'YPZ', 'CYPZ', 'Burns Lake Airport', NULL, 'CA', 'British Columbia', 54.3764000, -125.9510000, 'active', '2026-01-31 19:12:02', '2026-01-31 19:12:02'),
(1453, 'YQJ', NULL, 'April Point Seaplane Base', NULL, 'CA', 'British Columbia', 50.0650000, -125.2350000, 'active', '2026-01-31 19:12:02', '2026-01-31 19:12:02'),
(1454, 'YQQ', 'CYQQ', 'CFB Comox', NULL, 'CA', 'British Columbia', 49.7108000, -124.8870000, 'active', '2026-01-31 19:12:02', '2026-01-31 19:12:02'),
(1455, 'YQZ', 'CYQZ', 'Quesnel Airport', NULL, 'CA', 'British Columbia', 53.0261000, -122.5100000, 'active', '2026-01-31 19:12:03', '2026-01-31 19:12:03'),
(1456, 'YRC', NULL, 'Refuge Cove Water Aerodrome', NULL, 'CA', 'British Columbia', 50.1234000, -124.8430000, 'active', '2026-01-31 19:12:03', '2026-01-31 19:12:03'),
(1457, 'YRD', NULL, 'Dean River Airport', NULL, 'CA', 'British Columbia', 52.8237000, -126.9650000, 'active', '2026-01-31 19:12:03', '2026-01-31 19:12:03'),
(1458, 'YRN', NULL, 'Rivers Inlet Water Aerodrome', NULL, 'CA', 'British Columbia', 51.6840000, -127.2640000, 'active', '2026-01-31 19:12:04', '2026-01-31 19:12:04'),
(1459, 'YRR', NULL, 'Stuart Island Airport', NULL, 'CA', 'British Columbia', 50.4094000, -125.1320000, 'active', '2026-01-31 19:12:04', '2026-01-31 19:12:04'),
(1460, 'YRV', 'CYRV', 'Revelstoke Airport', NULL, 'CA', 'British Columbia', 50.9667000, -118.1830000, 'active', '2026-01-31 19:12:04', '2026-01-31 19:12:04'),
(1461, 'YSE', 'CYSE', 'Squamish Airport', NULL, 'CA', 'British Columbia', 49.7817000, -123.1620000, 'active', '2026-01-31 19:12:05', '2026-01-31 19:12:05'),
(1462, 'YSN', 'CZAM', 'Salmon Arm Airport', NULL, 'CA', 'British Columbia', 50.6828000, -119.2290000, 'active', '2026-01-31 19:12:05', '2026-01-31 19:12:05'),
(1463, 'YSX', NULL, 'Bella Bella/Shearwater Water Aerodrome', NULL, 'CA', 'British Columbia', 52.1500000, -128.0830000, 'active', '2026-01-31 19:12:05', '2026-01-31 19:12:05'),
(1464, 'YTB', NULL, 'Hartley Bay Water Aerodrome', NULL, 'CA', 'British Columbia', 53.4167000, -129.2500000, 'active', '2026-01-31 19:12:06', '2026-01-31 19:12:06'),
(1465, 'YTG', NULL, 'Sullivan Bay Water Aerodrome', NULL, 'CA', 'British Columbia', 50.8854000, -126.8310000, 'active', '2026-01-31 19:12:06', '2026-01-31 19:12:06'),
(1466, 'YTP', NULL, 'Tofino Harbour Water Aerodrome', NULL, 'CA', 'British Columbia', 49.1550000, -125.9100000, 'active', '2026-01-31 19:12:06', '2026-01-31 19:12:06'),
(1467, 'YTU', NULL, 'Tasu Water Aerodrome', NULL, 'CA', 'British Columbia', 52.7631000, -132.0400000, 'active', '2026-01-31 19:12:07', '2026-01-31 19:12:07'),
(1468, 'YTX', NULL, 'Telegraph Creek Airport', NULL, 'CA', 'British Columbia', 57.9167000, -131.1170000, 'active', '2026-01-31 19:12:07', '2026-01-31 19:12:07'),
(1469, 'YVE', 'CYVK', 'Vernon Regional Airport', NULL, 'CA', 'British Columbia', 50.2481000, -119.3310000, 'active', '2026-01-31 19:12:07', '2026-01-31 19:12:07'),
(1470, 'YVR', 'CYVR', 'Vancouver International Airport', NULL, 'CA', 'British Columbia', 49.1939000, -123.1840000, 'active', '2026-01-31 19:12:08', '2026-01-31 19:12:08'),
(1471, 'YWH', 'CYWH', 'Victoria Harbour Water Airport', NULL, 'CA', 'British Columbia', 48.4250000, -123.3890000, 'active', '2026-01-31 19:12:08', '2026-01-31 19:12:08'),
(1472, 'YWL', 'CYWL', 'Williams Lake Airport', NULL, 'CA', 'British Columbia', 52.1831000, -122.0540000, 'active', '2026-01-31 19:12:08', '2026-01-31 19:12:08'),
(1473, 'YWS', NULL, 'Whistler/Green Lake Water Aerodrome', NULL, 'CA', 'British Columbia', 50.1436000, -122.9490000, 'active', '2026-01-31 19:12:09', '2026-01-31 19:12:09'),
(1474, 'YXC', 'CYXC', 'Cranbrook/Canadian Rockies International Airport', NULL, 'CA', 'British Columbia', 49.6108000, -115.7820000, 'active', '2026-01-31 19:12:09', '2026-01-31 19:12:09'),
(1475, 'YXJ', 'CYXJ', 'Fort St. John Airport (North Peace Airport)', NULL, 'CA', 'British Columbia', 56.2381000, -120.7400000, 'active', '2026-01-31 19:12:09', '2026-01-31 19:12:09'),
(1476, 'YXS', 'CYXS', 'Prince George Airport', NULL, 'CA', 'British Columbia', 53.8894000, -122.6790000, 'active', '2026-01-31 19:12:10', '2026-01-31 19:12:10'),
(1477, 'YXT', 'CYXT', 'Northwest Regional Airport', NULL, 'CA', 'British Columbia', 54.4685000, -128.5760000, 'active', '2026-01-31 19:12:10', '2026-01-31 19:12:10'),
(1478, 'YXX', 'CYXX', 'Abbotsford International Airport', NULL, 'CA', 'British Columbia', 49.0253000, -122.3610000, 'active', '2026-01-31 19:12:10', '2026-01-31 19:12:10'),
(1479, 'YYD', 'CYYD', 'Smithers Airport', NULL, 'CA', 'British Columbia', 54.8247000, -127.1830000, 'active', '2026-01-31 19:12:11', '2026-01-31 19:12:11'),
(1480, 'YYE', 'CYYE', 'Northern Rockies Regional Airport', NULL, 'CA', 'British Columbia', 58.8364000, -122.5970000, 'active', '2026-01-31 19:12:11', '2026-01-31 19:12:11'),
(1481, 'YYF', 'CYYF', 'Penticton Regional Airport', NULL, 'CA', 'British Columbia', 49.4631000, -119.6020000, 'active', '2026-01-31 19:12:11', '2026-01-31 19:12:11'),
(1482, 'YYJ', 'CYYJ', 'Victoria International Airport', NULL, 'CA', 'British Columbia', 48.6469000, -123.4260000, 'active', '2026-01-31 19:12:12', '2026-01-31 19:12:12'),
(1483, 'YZA', NULL, 'Cache Creek Airport (Ashcroft Regional Airport)', NULL, 'CA', 'British Columbia', 50.7753000, -121.3210000, 'active', '2026-01-31 19:12:12', '2026-01-31 19:12:12'),
(1484, 'YZP', 'CYZP', 'Sandspit Airport', NULL, 'CA', 'British Columbia', 53.2543000, -131.8140000, 'active', '2026-01-31 19:12:12', '2026-01-31 19:12:12'),
(1485, 'YZT', 'CYZT', 'Port Hardy Airport', NULL, 'CA', 'British Columbia', 50.6806000, -127.3670000, 'active', '2026-01-31 19:12:13', '2026-01-31 19:12:13'),
(1486, 'YZZ', NULL, 'Trail Airport', NULL, 'CA', 'British Columbia', 49.0556000, -117.6090000, 'active', '2026-01-31 19:12:13', '2026-01-31 19:12:13'),
(1487, 'ZAA', NULL, 'Alice Arm/Silver City Water Aerodrome', NULL, 'CA', 'British Columbia', 55.4667000, -129.4830000, 'active', '2026-01-31 19:12:13', '2026-01-31 19:12:13'),
(1488, 'ZEL', 'CBBC', 'Bella Bella (Campbell Island) Airport', NULL, 'CA', 'British Columbia', 52.1850000, -128.1570000, 'active', '2026-01-31 19:12:14', '2026-01-31 19:12:14'),
(1489, 'ZGF', 'CZGF', 'Grand Forks Airport', NULL, 'CA', 'British Columbia', 49.0156000, -118.4310000, 'active', '2026-01-31 19:12:14', '2026-01-31 19:12:14'),
(1490, 'ZMH', 'CZML', 'South Cariboo Regional Airport', NULL, 'CA', 'British Columbia', 51.7361000, -121.3330000, 'active', '2026-01-31 19:12:14', '2026-01-31 19:12:14'),
(1491, 'ZMT', 'CZMT', 'Masset Airport', NULL, 'CA', 'British Columbia', 54.0275000, -132.1250000, 'active', '2026-01-31 19:12:15', '2026-01-31 19:12:15'),
(1492, 'ZNA', NULL, 'Nanaimo Harbour Water Airport', NULL, 'CA', 'British Columbia', 49.1833000, -123.9500000, 'active', '2026-01-31 19:12:15', '2026-01-31 19:12:15'),
(1493, 'ZNU', NULL, 'Namu Water Aerodrome', NULL, 'CA', 'British Columbia', 51.8628000, -127.8690000, 'active', '2026-01-31 19:12:15', '2026-01-31 19:12:15'),
(1494, 'ZOF', NULL, 'Ocean Falls Water Aerodrome', NULL, 'CA', 'British Columbia', 52.3667000, -127.7170000, 'active', '2026-01-31 19:12:16', '2026-01-31 19:12:16'),
(1495, 'ZQS', NULL, 'Queen Charlotte City Water Aerodrome', NULL, 'CA', 'British Columbia', 53.2670000, -132.0830000, 'active', '2026-01-31 19:12:16', '2026-01-31 19:12:16'),
(1496, 'ZST', 'CZST', 'Stewart Aerodrome', NULL, 'CA', 'British Columbia', 55.9354000, -129.9820000, 'active', '2026-01-31 19:12:16', '2026-01-31 19:12:16'),
(1497, 'ZSW', 'CZSW', 'Prince Rupert/Seal Cove Water Airport', NULL, 'CA', 'British Columbia', 54.3333000, -130.2830000, 'active', '2026-01-31 19:12:17', '2026-01-31 19:12:17'),
(1498, 'ZTS', NULL, 'Tahsis Water Aerodrome', NULL, 'CA', 'British Columbia', 49.9167000, -126.6670000, 'active', '2026-01-31 19:12:17', '2026-01-31 19:12:17'),
(1499, 'ILF', 'CZBD', 'Ilford Airport', NULL, 'CA', 'Manitoba', 56.0614000, -95.6139000, 'active', '2026-01-31 19:12:17', '2026-01-31 19:12:17'),
(1500, 'KES', 'CZEE', 'Kelsey Airport', NULL, 'CA', 'Manitoba', 56.0375000, -96.5097000, 'active', '2026-01-31 19:12:18', '2026-01-31 19:12:18'),
(1501, 'LRQ', NULL, 'Laurie River Airport', NULL, 'CA', 'Manitoba', 56.2486000, -101.3040000, 'active', '2026-01-31 19:12:18', '2026-01-31 19:12:18'),
(1502, 'PIW', 'CZMN', 'Pikwitonei Airport', NULL, 'CA', 'Manitoba', 55.5889000, -97.1642000, 'active', '2026-01-31 19:12:18', '2026-01-31 19:12:18'),
(1503, 'XGL', NULL, 'Granville Lake Airport', NULL, 'CA', 'Manitoba', 56.3000000, -100.5000000, 'active', '2026-01-31 19:12:19', '2026-01-31 19:12:19'),
(1504, 'XLB', 'CZWH', 'Lac Brochet Airport', NULL, 'CA', 'Manitoba', 58.6175000, -101.4690000, 'active', '2026-01-31 19:12:19', '2026-01-31 19:12:19'),
(1505, 'XPK', 'CZFG', 'Pukatawagan Airport', NULL, 'CA', 'Manitoba', 55.7492000, -101.2660000, 'active', '2026-01-31 19:12:19', '2026-01-31 19:12:19'),
(1506, 'XPP', 'CZNG', 'Poplar River Airport', NULL, 'CA', 'Manitoba', 52.9965000, -97.2742000, 'active', '2026-01-31 19:12:20', '2026-01-31 19:12:20'),
(1507, 'XSI', 'CZSN', 'South Indian Lake Airport', NULL, 'CA', 'Manitoba', 56.7928000, -98.9072000, 'active', '2026-01-31 19:12:20', '2026-01-31 19:12:20'),
(1508, 'XTL', 'CYBQ', 'Tadoule Lake Airport', NULL, 'CA', 'Manitoba', 58.7061000, -98.5122000, 'active', '2026-01-31 19:12:20', '2026-01-31 19:12:20'),
(1509, 'YAD', NULL, 'Moose Lake Airport', NULL, 'CA', 'Manitoba', 53.7063000, -100.3440000, 'active', '2026-01-31 19:12:21', '2026-01-31 19:12:21'),
(1510, 'YBR', 'CYBR', 'Brandon Municipal Airport (McGill Field)', NULL, 'CA', 'Manitoba', 49.9100000, -99.9519000, 'active', '2026-01-31 19:12:21', '2026-01-31 19:12:21'),
(1511, 'YBT', 'CYBT', 'Brochet Airport', NULL, 'CA', 'Manitoba', 57.8894000, -101.6790000, 'active', '2026-01-31 19:12:21', '2026-01-31 19:12:21'),
(1512, 'YBV', 'CYBV', 'Berens River Airport', NULL, 'CA', 'Manitoba', 52.3589000, -97.0183000, 'active', '2026-01-31 19:12:22', '2026-01-31 19:12:22'),
(1513, 'YCR', 'CYCR', 'Cross Lake (Charlie Sinclair Memorial) Airport', NULL, 'CA', 'Manitoba', 54.6106000, -97.7608000, 'active', '2026-01-31 19:12:22', '2026-01-31 19:12:22'),
(1514, 'YDN', 'CYDN', 'Lt. Col W.G. (Billy) Barker VC Airport', NULL, 'CA', 'Manitoba', 51.1008000, -100.0520000, 'active', '2026-01-31 19:12:22', '2026-01-31 19:12:22'),
(1515, 'YDV', 'CZTA', 'Bloodvein River Airport', NULL, 'CA', 'Manitoba', 51.7846000, -96.6923000, 'active', '2026-01-31 19:12:23', '2026-01-31 19:12:23'),
(1516, 'YFO', 'CYFO', 'Flin Flon Airport', NULL, 'CA', 'Manitoba', 54.6781000, -101.6820000, 'active', '2026-01-31 19:12:23', '2026-01-31 19:12:23'),
(1517, 'YGM', 'CYGM', 'Gimli Industrial Park Airport', NULL, 'CA', 'Manitoba', 50.6281000, -97.0433000, 'active', '2026-01-31 19:12:23', '2026-01-31 19:12:23'),
(1518, 'YGO', 'CYGO', 'Gods Lake Narrows Airport', NULL, 'CA', 'Manitoba', 54.5589000, -94.4914000, 'active', '2026-01-31 19:12:24', '2026-01-31 19:12:24'),
(1519, 'YGX', 'CYGX', 'Gillam Airport', NULL, 'CA', 'Manitoba', 56.3575000, -94.7106000, 'active', '2026-01-31 19:12:24', '2026-01-31 19:12:24'),
(1520, 'YIV', 'CYIV', 'Island Lake Airport (Garden Hill Airport)', NULL, 'CA', 'Manitoba', 53.8572000, -94.6536000, 'active', '2026-01-31 19:12:24', '2026-01-31 19:12:24'),
(1521, 'YKE', NULL, 'Knee Lake Airport', NULL, 'CA', 'Manitoba', 54.9153000, -94.7981000, 'active', '2026-01-31 19:12:25', '2026-01-31 19:12:25'),
(1522, 'YLR', 'CYLR', 'Leaf Rapids Airport', NULL, 'CA', 'Manitoba', 56.5133000, -99.9853000, 'active', '2026-01-31 19:12:25', '2026-01-31 19:12:25'),
(1523, 'YNE', 'CYNE', 'Norway House Airport', NULL, 'CA', 'Manitoba', 53.9583000, -97.8442000, 'active', '2026-01-31 19:12:25', '2026-01-31 19:12:25'),
(1524, 'YOH', 'CYOH', 'Oxford House Airport', NULL, 'CA', 'Manitoba', 54.9333000, -95.2789000, 'active', '2026-01-31 19:12:26', '2026-01-31 19:12:26'),
(1525, 'YPG', 'CYPG', 'Portage la Prairie/Southport Airport', NULL, 'CA', 'Manitoba', 49.9031000, -98.2738000, 'active', '2026-01-31 19:12:26', '2026-01-31 19:12:26'),
(1526, 'YQD', 'CYQD', 'The Pas Airport', NULL, 'CA', 'Manitoba', 53.9714000, -101.0910000, 'active', '2026-01-31 19:12:26', '2026-01-31 19:12:26'),
(1527, 'YRS', 'CYRS', 'Red Sucker Lake Airport', NULL, 'CA', 'Manitoba', 54.1672000, -93.5572000, 'active', '2026-01-31 19:12:27', '2026-01-31 19:12:27'),
(1528, 'YST', 'CYST', 'St. Theresa Point Airport', NULL, 'CA', 'Manitoba', 53.8456000, -94.8519000, 'active', '2026-01-31 19:12:27', '2026-01-31 19:12:27'),
(1529, 'YTD', 'CZLQ', 'Thicket Portage Airport', NULL, 'CA', 'Manitoba', 55.3189000, -97.7078000, 'active', '2026-01-31 19:12:27', '2026-01-31 19:12:27'),
(1530, 'YTH', 'CYTH', 'Thompson Airport', NULL, 'CA', 'Manitoba', 55.8011000, -97.8642000, 'active', '2026-01-31 19:12:28', '2026-01-31 19:12:28'),
(1531, 'YWG', 'CYWG', 'Winnipeg James Armstrong Richardson International Airport', NULL, 'CA', 'Manitoba', 49.9100000, -97.2399000, 'active', '2026-01-31 19:12:28', '2026-01-31 19:12:28'),
(1532, 'YYI', 'CYYI', 'Rivers Airport', NULL, 'CA', 'Manitoba', 50.0101000, -100.3140000, 'active', '2026-01-31 19:12:28', '2026-01-31 19:12:28'),
(1533, 'YYL', 'CYYL', 'Lynn Lake Airport', NULL, 'CA', 'Manitoba', 56.8639000, -101.0760000, 'active', '2026-01-31 19:12:29', '2026-01-31 19:12:29'),
(1534, 'YYQ', 'CYYQ', 'Churchill Airport', NULL, 'CA', 'Manitoba', 58.7392000, -94.0650000, 'active', '2026-01-31 19:12:29', '2026-01-31 19:12:29'),
(1535, 'ZAC', 'CZAC', 'York Landing Airport', NULL, 'CA', 'Manitoba', 56.0894000, -96.0892000, 'active', '2026-01-31 19:12:29', '2026-01-31 19:12:29'),
(1536, 'ZGI', 'CZGI', 'Gods River Airport', NULL, 'CA', 'Manitoba', 54.8397000, -94.0786000, 'active', '2026-01-31 19:12:30', '2026-01-31 19:12:30'),
(1537, 'ZGR', 'CZGR', 'Little Grand Rapids Airport', NULL, 'CA', 'Manitoba', 52.0456000, -95.4658000, 'active', '2026-01-31 19:12:30', '2026-01-31 19:12:30'),
(1538, 'ZJG', 'CZJG', 'Jenpeg Airport', NULL, 'CA', 'Manitoba', 54.5189000, -98.0461000, 'active', '2026-01-31 19:12:30', '2026-01-31 19:12:30'),
(1539, 'ZJN', 'CZJN', 'Swan River Airport', NULL, 'CA', 'Manitoba', 52.1206000, -101.2360000, 'active', '2026-01-31 19:12:31', '2026-01-31 19:12:31'),
(1540, 'ZTM', 'CZTM', 'Shamattawa Airport', NULL, 'CA', 'Manitoba', 55.8656000, -92.0814000, 'active', '2026-01-31 19:12:31', '2026-01-31 19:12:31'),
(1541, 'YCH', 'CYCH', 'Miramichi Airport', NULL, 'CA', 'New Brunswick', 47.0078000, -65.4492000, 'active', '2026-01-31 19:12:31', '2026-01-31 19:12:31'),
(1542, 'YCL', 'CYCL', 'Charlo Airport', NULL, 'CA', 'New Brunswick', 47.9908000, -66.3303000, 'active', '2026-01-31 19:12:32', '2026-01-31 19:12:32'),
(1543, 'YFC', 'CYFC', 'Fredericton International Airport', NULL, 'CA', 'New Brunswick', 45.8689000, -66.5372000, 'active', '2026-01-31 19:12:32', '2026-01-31 19:12:32'),
(1544, 'YQM', 'CYQM', 'Greater Moncton International Airport', NULL, 'CA', 'New Brunswick', 46.1122000, -64.6786000, 'active', '2026-01-31 19:12:32', '2026-01-31 19:12:32'),
(1545, 'YSJ', 'CYSJ', 'Saint John Airport', NULL, 'CA', 'New Brunswick', 45.3161000, -65.8903000, 'active', '2026-01-31 19:12:33', '2026-01-31 19:12:33'),
(1546, 'YSL', 'CYSL', 'Saint-Leonard Aerodrome', NULL, 'CA', 'New Brunswick', 47.1575000, -67.8347000, 'active', '2026-01-31 19:12:33', '2026-01-31 19:12:33'),
(1547, 'ZBF', 'CZBF', 'Bathurst Airport (New Brunswick)', NULL, 'CA', 'New Brunswick', 47.6297000, -65.7389000, 'active', '2026-01-31 19:12:33', '2026-01-31 19:12:33'),
(1548, 'YAY', 'CYAY', 'St. Anthony Airport', NULL, 'CA', 'Newfoundland and Labrador', 51.3919000, -56.0831000, 'active', '2026-01-31 19:12:34', '2026-01-31 19:12:34'),
(1549, 'YBI', NULL, 'Black Tickle Airport', NULL, 'CA', 'Newfoundland and Labrador', 53.4694000, -55.7850000, 'active', '2026-01-31 19:12:34', '2026-01-31 19:12:34'),
(1550, 'YDE', NULL, 'Paradise River Airport', NULL, 'CA', 'Newfoundland and Labrador', 53.4300000, -57.2333000, 'active', '2026-01-31 19:12:34', '2026-01-31 19:12:34'),
(1551, 'YDF', 'CYDF', 'Deer Lake Regional Airport', NULL, 'CA', 'Newfoundland and Labrador', 49.2108000, -57.3914000, 'active', '2026-01-31 19:12:35', '2026-01-31 19:12:35'),
(1552, 'YDP', 'CYDP', 'Nain Airport', NULL, 'CA', 'Newfoundland and Labrador', 56.5492000, -61.6803000, 'active', '2026-01-31 19:12:35', '2026-01-31 19:12:35'),
(1553, 'YFX', NULL, 'St. Lewis (Fox Harbour) Airport', NULL, 'CA', 'Newfoundland and Labrador', 52.3728000, -55.6739000, 'active', '2026-01-31 19:12:35', '2026-01-31 19:12:35'),
(1554, 'YHA', NULL, 'Port Hope Simpson Airport', NULL, 'CA', 'Newfoundland and Labrador', 52.5281000, -56.2861000, 'active', '2026-01-31 19:12:36', '2026-01-31 19:12:36'),
(1555, 'YHG', NULL, 'Charlottetown Airport', NULL, 'CA', 'Newfoundland and Labrador', 52.7655000, -56.1182000, 'active', '2026-01-31 19:12:36', '2026-01-31 19:12:36'),
(1556, 'YHO', 'CYHO', 'Hopedale Airport', NULL, 'CA', 'Newfoundland and Labrador', 55.4483000, -60.2286000, 'active', '2026-01-31 19:12:36', '2026-01-31 19:12:36'),
(1557, 'YJT', 'CYJT', 'Stephenville International Airport', NULL, 'CA', 'Newfoundland and Labrador', 48.5442000, -58.5500000, 'active', '2026-01-31 19:12:37', '2026-01-31 19:12:37'),
(1558, 'YMH', 'CYMH', 'Mary\'s Harbour Airport', NULL, 'CA', 'Newfoundland and Labrador', 52.3028000, -55.8472000, 'active', '2026-01-31 19:12:37', '2026-01-31 19:12:37'),
(1559, 'YMN', 'CYFT', 'Makkovik Airport', NULL, 'CA', 'Newfoundland and Labrador', 55.0769000, -59.1864000, 'active', '2026-01-31 19:12:37', '2026-01-31 19:12:37'),
(1560, 'YNP', NULL, 'Natuashish Airport', NULL, 'CA', 'Newfoundland and Labrador', 55.9139000, -61.1844000, 'active', '2026-01-31 19:12:38', '2026-01-31 19:12:38'),
(1561, 'YQX', 'CYQX', 'Gander International Airport / CFB Gander', NULL, 'CA', 'Newfoundland and Labrador', 48.9369000, -54.5681000, 'active', '2026-01-31 19:12:38', '2026-01-31 19:12:38'),
(1562, 'YRF', 'CYCA', 'Cartwright Airport', NULL, 'CA', 'Newfoundland and Labrador', 53.6828000, -57.0419000, 'active', '2026-01-31 19:12:38', '2026-01-31 19:12:38'),
(1563, 'YRG', NULL, 'Rigolet Airport', NULL, 'CA', 'Newfoundland and Labrador', 54.1797000, -58.4575000, 'active', '2026-01-31 19:12:39', '2026-01-31 19:12:39'),
(1564, 'YSO', NULL, 'Postville Airport', NULL, 'CA', 'Newfoundland and Labrador', 54.9105000, -59.7851000, 'active', '2026-01-31 19:12:39', '2026-01-31 19:12:39'),
(1565, 'YWK', 'CYWK', 'Wabush Airport', NULL, 'CA', 'Newfoundland and Labrador', 52.9219000, -66.8644000, 'active', '2026-01-31 19:12:39', '2026-01-31 19:12:39'),
(1566, 'YWM', NULL, 'Williams Harbour Airport', NULL, 'CA', 'Newfoundland and Labrador', 52.5669000, -55.7847000, 'active', '2026-01-31 19:12:40', '2026-01-31 19:12:40'),
(1567, 'YYR', 'CYYR', 'CFB Goose Bay', NULL, 'CA', 'Newfoundland and Labrador', 53.3192000, -60.4258000, 'active', '2026-01-31 19:12:40', '2026-01-31 19:12:40'),
(1568, 'YYT', 'CYYT', 'St. John\'s International Airport', NULL, 'CA', 'Newfoundland and Labrador', 47.6186000, -52.7519000, 'active', '2026-01-31 19:12:40', '2026-01-31 19:12:40'),
(1569, 'ZUM', 'CZUM', 'Churchill Falls Airport', NULL, 'CA', 'Newfoundland and Labrador', 53.5619000, -64.1064000, 'active', '2026-01-31 19:12:41', '2026-01-31 19:12:41'),
(1570, 'DAS', NULL, 'Great Bear Lake Airport', NULL, 'CA', 'Northwest Territories', 66.7031000, -119.7070000, 'active', '2026-01-31 19:12:41', '2026-01-31 19:12:41'),
(1571, 'DVK', NULL, 'Diavik Airport', NULL, 'CA', 'Northwest Territories', 64.5114000, -110.2890000, 'active', '2026-01-31 19:12:41', '2026-01-31 19:12:41'),
(1572, 'GHK', NULL, 'Gahcho Kue Aerodrome', NULL, 'CA', 'Northwest Territories', 63.4265000, -109.1930000, 'active', '2026-01-31 19:12:43', '2026-01-31 19:12:43'),
(1573, 'GSL', NULL, 'Taltheilei Narrows Airport', NULL, 'CA', 'Northwest Territories', 62.5981000, -111.5430000, 'active', '2026-01-31 19:12:43', '2026-01-31 19:12:43'),
(1574, 'LAK', 'CYKD', 'Aklavik/Freddie Carmichael Airport', NULL, 'CA', 'Northwest Territories', 68.2233000, -135.0060000, 'active', '2026-01-31 19:12:43', '2026-01-31 19:12:43'),
(1575, 'TNS', NULL, 'Tungsten (Cantung) Airport', NULL, 'CA', 'Northwest Territories', 61.9569000, -128.2030000, 'active', '2026-01-31 19:12:44', '2026-01-31 19:12:44'),
(1576, 'YCK', 'CYVL', 'Colville Lake/Tommy Kochon Aerodrome', NULL, 'CA', 'Northwest Territories', 67.0200000, -126.1260000, 'active', '2026-01-31 19:12:44', '2026-01-31 19:12:44'),
(1577, 'YDU', NULL, 'Kasba Lake Airport', NULL, 'CA', 'Northwest Territories', 60.2919000, -102.5020000, 'active', '2026-01-31 19:12:45', '2026-01-31 19:12:45'),
(1578, 'YDW', NULL, 'Obre Lake/North of Sixty Airport', NULL, 'CA', 'Northwest Territories', 60.3164000, -103.1290000, 'active', '2026-01-31 19:12:45', '2026-01-31 19:12:45'),
(1579, 'YEV', 'CYEV', 'Inuvik (Mike Zubko) Airport', NULL, 'CA', 'Northwest Territories', 68.3042000, -133.4830000, 'active', '2026-01-31 19:12:46', '2026-01-31 19:12:46'),
(1580, 'YFJ', 'CYWE', 'Wekweeti Airport', NULL, 'CA', 'Northwest Territories', 64.1908000, -114.0770000, 'active', '2026-01-31 19:12:46', '2026-01-31 19:12:46'),
(1581, 'YFL', NULL, 'Fort Reliance Water Aerodrome (CJN8)', NULL, 'CA', 'Northwest Territories', 62.7000000, -109.1670000, 'active', '2026-01-31 19:12:46', '2026-01-31 19:12:46'),
(1582, 'YFR', 'CYFR', 'Fort Resolution Airport', NULL, 'CA', 'Northwest Territories', 61.1808000, -113.6900000, 'active', '2026-01-31 19:12:47', '2026-01-31 19:12:47'),
(1583, 'YFS', 'CYFS', 'Fort Simpson Airport', NULL, 'CA', 'Northwest Territories', 61.7602000, -121.2370000, 'active', '2026-01-31 19:12:47', '2026-01-31 19:12:47'),
(1584, 'YGH', 'CYGH', 'Fort Good Hope Airport', NULL, 'CA', 'Northwest Territories', 66.2408000, -128.6510000, 'active', '2026-01-31 19:12:47', '2026-01-31 19:12:47'),
(1585, 'YHI', 'CYHI', 'Ulukhaktok/Holman Airport', NULL, 'CA', 'Northwest Territories', 70.7628000, -117.8060000, 'active', '2026-01-31 19:12:48', '2026-01-31 19:12:48'),
(1586, 'YHY', 'CYHY', 'Hay River/Merlyn Carter Airport', NULL, 'CA', 'Northwest Territories', 60.8397000, -115.7830000, 'active', '2026-01-31 19:12:48', '2026-01-31 19:12:48'),
(1587, 'YJF', 'CYJF', 'Fort Liard Airport', NULL, 'CA', 'Northwest Territories', 60.2358000, -123.4690000, 'active', '2026-01-31 19:12:48', '2026-01-31 19:12:48'),
(1588, 'YLE', NULL, 'Whati Airport', NULL, 'CA', 'Northwest Territories', 63.1317000, -117.2460000, 'active', '2026-01-31 19:12:49', '2026-01-31 19:12:49'),
(1589, 'YMD', 'CYMD', 'Mould Bay Airport', NULL, 'CA', 'Northwest Territories', 76.2392000, -119.3220000, 'active', '2026-01-31 19:12:49', '2026-01-31 19:12:49'),
(1590, 'YNX', NULL, 'Snap Lake Airport', NULL, 'CA', 'Northwest Territories', 63.5936000, -110.9060000, 'active', '2026-01-31 19:12:49', '2026-01-31 19:12:49'),
(1591, 'YOA', 'CYOA', 'Ekati Airport', NULL, 'CA', 'Northwest Territories', 64.6989000, -110.6150000, 'active', '2026-01-31 19:12:50', '2026-01-31 19:12:50'),
(1592, 'YPC', 'CYPC', 'Nora Aliqatchialuk Ruben Airport', NULL, 'CA', 'Northwest Territories', 69.3608000, -124.0750000, 'active', '2026-01-31 19:12:50', '2026-01-31 19:12:50'),
(1593, 'YRA', 'CYRA', 'Gameti/Rae Lakes Airport', NULL, 'CA', 'Northwest Territories', 64.1161000, -117.3100000, 'active', '2026-01-31 19:12:50', '2026-01-31 19:12:50'),
(1594, 'YSG', 'CYLK', 'Lutselk\'e Airport', NULL, 'CA', 'Northwest Territories', 62.4183000, -110.6820000, 'active', '2026-01-31 19:12:51', '2026-01-31 19:12:51'),
(1595, 'YSM', 'CYSM', 'Fort Smith Airport', NULL, 'CA', 'Northwest Territories', 60.0203000, -111.9620000, 'active', '2026-01-31 19:12:51', '2026-01-31 19:12:51'),
(1596, 'YSY', 'CYSY', 'Sachs Harbour (David Nasogaluak Jr. Saaryuaq) Airport', NULL, 'CA', 'Northwest Territories', 71.9939000, -125.2430000, 'active', '2026-01-31 19:12:51', '2026-01-31 19:12:51'),
(1597, 'YUB', 'CYUB', 'Tuktoyaktuk/James Gruben Airport', NULL, 'CA', 'Northwest Territories', 69.4333000, -133.0260000, 'active', '2026-01-31 19:12:52', '2026-01-31 19:12:52'),
(1598, 'YVQ', 'CYVQ', 'Norman Wells Airport', NULL, 'CA', 'Northwest Territories', 65.2816000, -126.7980000, 'active', '2026-01-31 19:12:52', '2026-01-31 19:12:52'),
(1599, 'YWJ', 'CYWJ', 'Deline Airport', NULL, 'CA', 'Northwest Territories', 65.2111000, -123.4360000, 'active', '2026-01-31 19:12:52', '2026-01-31 19:12:52'),
(1600, 'YWY', 'CYWY', 'Wrigley Airport', NULL, 'CA', 'Northwest Territories', 63.2094000, -123.4370000, 'active', '2026-01-31 19:12:53', '2026-01-31 19:12:53'),
(1601, 'YZF', 'CYZF', 'Yellowknife Airport', NULL, 'CA', 'Northwest Territories', 62.4628000, -114.4400000, 'active', '2026-01-31 19:12:53', '2026-01-31 19:12:53'),
(1602, 'ZFM', 'CZFM', 'Fort McPherson Airport', NULL, 'CA', 'Northwest Territories', 67.4075000, -134.8610000, 'active', '2026-01-31 19:12:54', '2026-01-31 19:12:54');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(1603, 'ZFN', 'CZFN', 'Tulita Airport', NULL, 'CA', 'Northwest Territories', 64.9097000, -125.5730000, 'active', '2026-01-31 19:12:54', '2026-01-31 19:12:54'),
(1604, 'YDG', 'CYID', 'Digby/Annapolis Regional Airport', NULL, 'CA', 'Nova Scotia', 44.5458000, -65.7854000, 'active', '2026-01-31 19:12:54', '2026-01-31 19:12:54'),
(1605, 'YHZ', 'CYHZ', 'Halifax Stanfield International Airport', NULL, 'CA', 'Nova Scotia', 44.8808000, -63.5086000, 'active', '2026-01-31 19:12:55', '2026-01-31 19:12:55'),
(1606, 'YPS', 'CYPD', 'Port Hawkesbury Airport', NULL, 'CA', 'Nova Scotia', 45.6567000, -61.3681000, 'active', '2026-01-31 19:12:55', '2026-01-31 19:12:55'),
(1607, 'YQI', 'CYQI', 'Yarmouth Airport', NULL, 'CA', 'Nova Scotia', 43.8269000, -66.0881000, 'active', '2026-01-31 19:12:55', '2026-01-31 19:12:55'),
(1608, 'YQY', 'CYQY', 'Sydney/J.A. Douglas McCurdy Airport', NULL, 'CA', 'Nova Scotia', 46.1614000, -60.0478000, 'active', '2026-01-31 19:12:56', '2026-01-31 19:12:56'),
(1609, 'YSA', NULL, 'Sable Island Aerodrome', NULL, 'CA', 'Nova Scotia', 43.9303000, -59.9603000, 'active', '2026-01-31 19:12:56', '2026-01-31 19:12:56'),
(1610, 'YZX', 'CYZX', 'CFB Greenwood', NULL, 'CA', 'Nova Scotia', 44.9844000, -64.9169000, 'active', '2026-01-31 19:12:56', '2026-01-31 19:12:56'),
(1611, 'JOJ', NULL, 'Doris Lake Aerodrome', NULL, 'CA', 'Nunavut', 68.1253000, -106.5850000, 'active', '2026-01-31 19:12:57', '2026-01-31 19:12:57'),
(1612, 'UZM', NULL, 'Hope Bay Aerodrome', NULL, 'CA', 'Nunavut', 68.1560000, -106.6180000, 'active', '2026-01-31 19:12:57', '2026-01-31 19:12:57'),
(1613, 'YAB', 'CYAB', 'Arctic Bay Airport', NULL, 'CA', 'Nunavut', 73.0058000, -85.0425000, 'active', '2026-01-31 19:12:57', '2026-01-31 19:12:57'),
(1614, 'YBB', 'CYBB', 'Kugaaruk Airport', NULL, 'CA', 'Nunavut', 68.5344000, -89.8081000, 'active', '2026-01-31 19:12:58', '2026-01-31 19:12:58'),
(1615, 'YBK', 'CYBK', 'Baker Lake Airport', NULL, 'CA', 'Nunavut', 64.2989000, -96.0778000, 'active', '2026-01-31 19:12:58', '2026-01-31 19:12:58'),
(1616, 'YCB', 'CYCB', 'Cambridge Bay Airport', NULL, 'CA', 'Nunavut', 69.1081000, -105.1380000, 'active', '2026-01-31 19:12:58', '2026-01-31 19:12:58'),
(1617, 'YCO', 'CYCO', 'Kugluktuk Airport', NULL, 'CA', 'Nunavut', 67.8167000, -115.1440000, 'active', '2026-01-31 19:12:59', '2026-01-31 19:12:59'),
(1618, 'YCS', 'CYCS', 'Chesterfield Inlet Airport', NULL, 'CA', 'Nunavut', 63.3469000, -90.7311000, 'active', '2026-01-31 19:12:59', '2026-01-31 19:12:59'),
(1619, 'YCY', 'CYCY', 'Clyde River Airport', NULL, 'CA', 'Nunavut', 70.4861000, -68.5167000, 'active', '2026-01-31 19:12:59', '2026-01-31 19:12:59'),
(1620, 'YEK', 'CYEK', 'Arviat Airport', NULL, 'CA', 'Nunavut', 61.0942000, -94.0708000, 'active', '2026-01-31 19:13:00', '2026-01-31 19:13:00'),
(1621, 'YEU', 'CYEU', 'Eureka Aerodrome', NULL, 'CA', 'Nunavut', 79.9947000, -85.8142000, 'active', '2026-01-31 19:13:00', '2026-01-31 19:13:00'),
(1622, 'YFB', 'CYFB', 'Iqaluit Airport', NULL, 'CA', 'Nunavut', 63.7564000, -68.5558000, 'active', '2026-01-31 19:13:00', '2026-01-31 19:13:00'),
(1623, 'YGT', 'CYGT', 'Igloolik Airport', NULL, 'CA', 'Nunavut', 69.3647000, -81.8161000, 'active', '2026-01-31 19:13:01', '2026-01-31 19:13:01'),
(1624, 'YGZ', 'CYGZ', 'Grise Fiord Airport', NULL, 'CA', 'Nunavut', 76.4261000, -82.9092000, 'active', '2026-01-31 19:13:01', '2026-01-31 19:13:01'),
(1625, 'YHK', 'CYHK', 'Gjoa Haven Airport', NULL, 'CA', 'Nunavut', 68.6356000, -95.8497000, 'active', '2026-01-31 19:13:01', '2026-01-31 19:13:01'),
(1626, 'YIO', 'CYIO', 'Pond Inlet Airport', NULL, 'CA', 'Nunavut', 72.6833000, -77.9667000, 'active', '2026-01-31 19:13:02', '2026-01-31 19:13:02'),
(1627, 'YLC', 'CYLC', 'Kimmirut Airport', NULL, 'CA', 'Nunavut', 62.8500000, -69.8833000, 'active', '2026-01-31 19:13:02', '2026-01-31 19:13:02'),
(1628, 'YLT', 'CYLT', 'Alert Airport', NULL, 'CA', 'Nunavut', 82.5178000, -62.2806000, 'active', '2026-01-31 19:13:02', '2026-01-31 19:13:02'),
(1629, 'YMV', NULL, 'Mary River Aerodrome', NULL, 'CA', 'Nunavut', 71.3242000, -79.3569000, 'active', '2026-01-31 19:13:03', '2026-01-31 19:13:03'),
(1630, 'YRB', 'CYRB', 'Resolute Bay Airport', NULL, 'CA', 'Nunavut', 74.7169000, -94.9694000, 'active', '2026-01-31 19:13:03', '2026-01-31 19:13:03'),
(1631, 'YRT', 'CYRT', 'Rankin Inlet Airport', NULL, 'CA', 'Nunavut', 62.8114000, -92.1158000, 'active', '2026-01-31 19:13:03', '2026-01-31 19:13:03'),
(1632, 'YSK', 'CYSK', 'Sanikiluaq Airport', NULL, 'CA', 'Nunavut', 56.5378000, -79.2467000, 'active', '2026-01-31 19:13:04', '2026-01-31 19:13:04'),
(1633, 'YTE', 'CYTE', 'Cape Dorset Airport', NULL, 'CA', 'Nunavut', 64.2300000, -76.5267000, 'active', '2026-01-31 19:13:04', '2026-01-31 19:13:04'),
(1634, 'YUT', 'CYUT', 'Repulse Bay Airport', NULL, 'CA', 'Nunavut', 66.5214000, -86.2247000, 'active', '2026-01-31 19:13:04', '2026-01-31 19:13:04'),
(1635, 'YUX', 'CYUX', 'Hall Beach Airport', NULL, 'CA', 'Nunavut', 68.7761000, -81.2425000, 'active', '2026-01-31 19:13:05', '2026-01-31 19:13:05'),
(1636, 'YVM', 'CYVM', 'Qikiqtarjuaq Airport', NULL, 'CA', 'Nunavut', 67.5458000, -64.0314000, 'active', '2026-01-31 19:13:05', '2026-01-31 19:13:05'),
(1637, 'YVN', 'CYVN', 'Cape Dyer Airport', NULL, 'CA', 'Nunavut', 66.5930000, -61.5776000, 'active', '2026-01-31 19:13:05', '2026-01-31 19:13:05'),
(1638, 'YXN', 'CYXN', 'Whale Cove Airport', NULL, 'CA', 'Nunavut', 62.2400000, -92.5981000, 'active', '2026-01-31 19:13:06', '2026-01-31 19:13:06'),
(1639, 'YXP', 'CYXP', 'Pangnirtung Airport', NULL, 'CA', 'Nunavut', 66.1450000, -65.7136000, 'active', '2026-01-31 19:13:06', '2026-01-31 19:13:06'),
(1640, 'YYH', 'CYYH', 'Taloyoak Airport', NULL, 'CA', 'Nunavut', 69.5467000, -93.5767000, 'active', '2026-01-31 19:13:06', '2026-01-31 19:13:06'),
(1641, 'YZS', 'CYZS', 'Coral Harbour Airport', NULL, 'CA', 'Nunavut', 64.1933000, -83.3594000, 'active', '2026-01-31 19:13:07', '2026-01-31 19:13:07'),
(1642, 'KEW', NULL, 'Keewaywin Airport', NULL, 'CA', 'Ontario', 52.9911000, -92.8364000, 'active', '2026-01-31 19:13:07', '2026-01-31 19:13:07'),
(1643, 'KIF', NULL, 'Kingfisher Lake Airport', NULL, 'CA', 'Ontario', 53.0125000, -89.8553000, 'active', '2026-01-31 19:13:07', '2026-01-31 19:13:07'),
(1644, 'MSA', 'CZMD', 'Muskrat Dam Airport', NULL, 'CA', 'Ontario', 53.4414000, -91.7628000, 'active', '2026-01-31 19:13:08', '2026-01-31 19:13:08'),
(1645, 'SUR', NULL, 'Summer Beaver Airport', NULL, 'CA', 'Ontario', 52.7086000, -88.5419000, 'active', '2026-01-31 19:13:08', '2026-01-31 19:13:08'),
(1646, 'WNN', NULL, 'Wunnummin Lake Airport', NULL, 'CA', 'Ontario', 52.8939000, -89.2892000, 'active', '2026-01-31 19:13:08', '2026-01-31 19:13:08'),
(1647, 'XBE', NULL, 'Bearskin Lake Airport', NULL, 'CA', 'Ontario', 53.9656000, -91.0272000, 'active', '2026-01-31 19:13:09', '2026-01-31 19:13:09'),
(1648, 'XBR', NULL, 'Brockville Regional Tackaberry Airport', NULL, 'CA', 'Ontario', 44.6394000, -75.7503000, 'active', '2026-01-31 19:13:09', '2026-01-31 19:13:09'),
(1649, 'XCM', 'CYCK', 'Chatham-Kent Airport', NULL, 'CA', 'Ontario', 42.3064000, -82.0819000, 'active', '2026-01-31 19:13:09', '2026-01-31 19:13:09'),
(1650, 'XKS', 'CYAQ', 'Kasabonika Airport', NULL, 'CA', 'Ontario', 53.5247000, -88.6428000, 'active', '2026-01-31 19:13:10', '2026-01-31 19:13:10'),
(1651, 'YAC', 'CYAC', 'Cat Lake Airport', NULL, 'CA', 'Ontario', 51.7272000, -91.8244000, 'active', '2026-01-31 19:13:10', '2026-01-31 19:13:10'),
(1652, 'YAG', 'CYAG', 'Fort Frances Municipal Airport', NULL, 'CA', 'Ontario', 48.6542000, -93.4397000, 'active', '2026-01-31 19:13:11', '2026-01-31 19:13:11'),
(1653, 'YAM', 'CYAM', 'Sault Ste. Marie Airport', NULL, 'CA', 'Ontario', 46.4850000, -84.5094000, 'active', '2026-01-31 19:13:11', '2026-01-31 19:13:11'),
(1654, 'YAT', 'CYAT', 'Attawapiskat Airport', NULL, 'CA', 'Ontario', 52.9275000, -82.4319000, 'active', '2026-01-31 19:13:11', '2026-01-31 19:13:11'),
(1655, 'YAX', NULL, 'Angling Lake/Wapekeka Airport', NULL, 'CA', 'Ontario', 53.8492000, -89.5794000, 'active', '2026-01-31 19:13:12', '2026-01-31 19:13:12'),
(1656, 'YBS', NULL, 'Opapimiskan Lake Airport', NULL, 'CA', 'Ontario', 52.6067000, -90.3769000, 'active', '2026-01-31 19:13:12', '2026-01-31 19:13:12'),
(1657, 'YCC', 'CYCC', 'Cornwall Regional Airport', NULL, 'CA', 'Ontario', 45.0928000, -74.5633000, 'active', '2026-01-31 19:13:12', '2026-01-31 19:13:12'),
(1658, 'YCE', 'CYCE', 'Centralia/James T. Field Memorial Aerodrome', NULL, 'CA', 'Ontario', 43.2856000, -81.5083000, 'active', '2026-01-31 19:13:13', '2026-01-31 19:13:13'),
(1659, 'YCM', 'CYSN', 'St. Catharines/Niagara District Airport', NULL, 'CA', 'Ontario', 43.1917000, -79.1717000, 'active', '2026-01-31 19:13:13', '2026-01-31 19:13:13'),
(1660, 'YCN', 'CYCN', 'Cochrane Aerodrome', NULL, 'CA', 'Ontario', 49.1056000, -81.0136000, 'active', '2026-01-31 19:13:13', '2026-01-31 19:13:13'),
(1661, 'YEB', NULL, 'Bar River Airport', NULL, 'CA', 'Ontario', 46.4203000, -84.0922000, 'active', '2026-01-31 19:13:14', '2026-01-31 19:13:14'),
(1662, 'YEL', 'CYEL', 'Elliot Lake Municipal Airport', NULL, 'CA', 'Ontario', 46.3514000, -82.5614000, 'active', '2026-01-31 19:13:14', '2026-01-31 19:13:14'),
(1663, 'YEM', 'CYEM', 'Manitowaning/Manitoulin East Municipal Airport', NULL, 'CA', 'Ontario', 45.8428000, -81.8581000, 'active', '2026-01-31 19:13:14', '2026-01-31 19:13:14'),
(1664, 'YER', 'CYER', 'Fort Severn Airport', NULL, 'CA', 'Ontario', 56.0189000, -87.6761000, 'active', '2026-01-31 19:13:15', '2026-01-31 19:13:15'),
(1665, 'YFA', 'CYFA', 'Fort Albany Airport', NULL, 'CA', 'Ontario', 52.2014000, -81.6969000, 'active', '2026-01-31 19:13:15', '2026-01-31 19:13:15'),
(1666, 'YFH', 'CYFH', 'Fort Hope Airport', NULL, 'CA', 'Ontario', 51.5619000, -87.9078000, 'active', '2026-01-31 19:13:15', '2026-01-31 19:13:15'),
(1667, 'YGK', 'CYGK', 'Kingston/Norman Rogers Airport', NULL, 'CA', 'Ontario', 44.2253000, -76.5969000, 'active', '2026-01-31 19:13:16', '2026-01-31 19:13:16'),
(1668, 'YGQ', 'CYGQ', 'Geraldton (Greenstone Regional) Airport', NULL, 'CA', 'Ontario', 49.7783000, -86.9394000, 'active', '2026-01-31 19:13:16', '2026-01-31 19:13:16'),
(1669, 'YHD', 'CYHD', 'Dryden Regional Airport', NULL, 'CA', 'Ontario', 49.8317000, -92.7442000, 'active', '2026-01-31 19:13:16', '2026-01-31 19:13:16'),
(1670, 'YHF', 'CYHF', 'Hearst Municipal Airport', NULL, 'CA', 'Ontario', 49.7142000, -83.6861000, 'active', '2026-01-31 19:13:17', '2026-01-31 19:13:17'),
(1671, 'YHM', 'CYHM', 'John C. Munro Hamilton International Airport', NULL, 'CA', 'Ontario', 43.1736000, -79.9350000, 'active', '2026-01-31 19:13:17', '2026-01-31 19:13:17'),
(1672, 'YHN', 'CYHN', 'Hornepayne Municipal Airport', NULL, 'CA', 'Ontario', 49.1931000, -84.7589000, 'active', '2026-01-31 19:13:17', '2026-01-31 19:13:17'),
(1673, 'YHP', 'CYHP', 'Poplar Hill Airport', NULL, 'CA', 'Ontario', 52.1133000, -94.2556000, 'active', '2026-01-31 19:13:18', '2026-01-31 19:13:18'),
(1674, 'YIB', 'CYIB', 'Atikokan Municipal Airport', NULL, 'CA', 'Ontario', 48.7739000, -91.6386000, 'active', '2026-01-31 19:13:18', '2026-01-31 19:13:18'),
(1675, 'YKD', 'CYKM', 'Kincardine Municipal Airport', NULL, 'CA', 'Ontario', 44.2014000, -81.6067000, 'active', '2026-01-31 19:13:18', '2026-01-31 19:13:18'),
(1676, 'YKF', 'CYKF', 'Region of Waterloo International Airport', NULL, 'CA', 'Ontario', 43.4558000, -80.3858000, 'active', '2026-01-31 19:13:19', '2026-01-31 19:13:19'),
(1677, 'YKX', 'CYKX', 'Kirkland Lake Airport', NULL, 'CA', 'Ontario', 48.2103000, -79.9814000, 'active', '2026-01-31 19:13:19', '2026-01-31 19:13:19'),
(1678, 'YLD', 'CYLD', 'Chapleau Airport', NULL, 'CA', 'Ontario', 47.8200000, -83.3467000, 'active', '2026-01-31 19:13:19', '2026-01-31 19:13:19'),
(1679, 'YLH', 'CYLH', 'Lansdowne House Airport', NULL, 'CA', 'Ontario', 52.1956000, -87.9342000, 'active', '2026-01-31 19:13:20', '2026-01-31 19:13:20'),
(1680, 'YLK', 'CYLS', 'Lake Simcoe Regional Airport', NULL, 'CA', 'Ontario', 44.4853000, -79.5556000, 'active', '2026-01-31 19:13:20', '2026-01-31 19:13:20'),
(1681, 'YMG', 'CYMG', 'Manitouwadge Airport', NULL, 'CA', 'Ontario', 49.0839000, -85.8606000, 'active', '2026-01-31 19:13:20', '2026-01-31 19:13:20'),
(1682, 'YMO', 'CYMO', 'Moosonee Airport', NULL, 'CA', 'Ontario', 51.2911000, -80.6078000, 'active', '2026-01-31 19:13:21', '2026-01-31 19:13:21'),
(1683, 'YNO', NULL, 'North Spirit Lake Airport', NULL, 'CA', 'Ontario', 52.4900000, -92.9711000, 'active', '2026-01-31 19:13:21', '2026-01-31 19:13:21'),
(1684, 'YOG', 'CYKP', 'Ogoki Post Airport', NULL, 'CA', 'Ontario', 51.6586000, -85.9017000, 'active', '2026-01-31 19:13:21', '2026-01-31 19:13:21'),
(1685, 'YOO', 'CYOO', 'Oshawa Airport', NULL, 'CA', 'Ontario', 43.9228000, -78.8950000, 'active', '2026-01-31 19:13:22', '2026-01-31 19:13:22'),
(1686, 'YOS', 'CYOS', 'Billy Bishop Regional Airport', NULL, 'CA', 'Ontario', 44.5903000, -80.8375000, 'active', '2026-01-31 19:13:22', '2026-01-31 19:13:22'),
(1687, 'YOW', 'CYOW', 'Ottawa Macdonald-Cartier International Airport', NULL, 'CA', 'Ontario', 45.3225000, -75.6692000, 'active', '2026-01-31 19:13:22', '2026-01-31 19:13:22'),
(1688, 'YPD', NULL, 'Parry Sound Area Municipal Airport', NULL, 'CA', 'Ontario', 45.2575000, -79.8297000, 'active', '2026-01-31 19:13:23', '2026-01-31 19:13:23'),
(1689, 'YPL', 'CYPL', 'Pickle Lake Airport', NULL, 'CA', 'Ontario', 51.4464000, -90.2142000, 'active', '2026-01-31 19:13:23', '2026-01-31 19:13:23'),
(1690, 'YPM', 'CYPM', 'Pikangikum Airport', NULL, 'CA', 'Ontario', 51.8197000, -93.9733000, 'active', '2026-01-31 19:13:23', '2026-01-31 19:13:23'),
(1691, 'YPO', 'CYPO', 'Peawanuck Airport', NULL, 'CA', 'Ontario', 54.9881000, -85.4433000, 'active', '2026-01-31 19:13:24', '2026-01-31 19:13:24'),
(1692, 'YPQ', 'CYPQ', 'Peterborough Airport', NULL, 'CA', 'Ontario', 44.2300000, -78.3633000, 'active', '2026-01-31 19:13:24', '2026-01-31 19:13:24'),
(1693, 'YQA', 'CYQA', 'Muskoka Airport', NULL, 'CA', 'Ontario', 44.9747000, -79.3033000, 'active', '2026-01-31 19:13:24', '2026-01-31 19:13:24'),
(1694, 'YQG', 'CYQG', 'Windsor International Airport', NULL, 'CA', 'Ontario', 42.2756000, -82.9556000, 'active', '2026-01-31 19:13:25', '2026-01-31 19:13:25'),
(1695, 'YQK', 'CYQK', 'Kenora Airport', NULL, 'CA', 'Ontario', 49.7883000, -94.3631000, 'active', '2026-01-31 19:13:25', '2026-01-31 19:13:25'),
(1696, 'YQN', 'CYQN', 'Nakina Airport', NULL, 'CA', 'Ontario', 50.1828000, -86.6964000, 'active', '2026-01-31 19:13:25', '2026-01-31 19:13:25'),
(1697, 'YQS', 'CYQS', 'St. Thomas Municipal Airport', NULL, 'CA', 'Ontario', 42.7700000, -81.1108000, 'active', '2026-01-31 19:13:26', '2026-01-31 19:13:26'),
(1698, 'YQT', 'CYQT', 'Thunder Bay International Airport', NULL, 'CA', 'Ontario', 48.3719000, -89.3239000, 'active', '2026-01-31 19:13:26', '2026-01-31 19:13:26'),
(1699, 'YRL', 'CYRL', 'Red Lake Airport', NULL, 'CA', 'Ontario', 51.0669000, -93.7931000, 'active', '2026-01-31 19:13:26', '2026-01-31 19:13:26'),
(1700, 'YRO', 'CYRO', 'Ottawa/Rockcliffe Airport', NULL, 'CA', 'Ontario', 45.4603000, -75.6461000, 'active', '2026-01-31 19:13:27', '2026-01-31 19:13:27'),
(1701, 'YSB', 'CYSB', 'Sudbury Airport', NULL, 'CA', 'Ontario', 46.6250000, -80.7989000, 'active', '2026-01-31 19:13:27', '2026-01-31 19:13:27'),
(1702, 'YSH', 'CYSH', 'Smiths Falls-Montague Airport', NULL, 'CA', 'Ontario', 44.9458000, -75.9406000, 'active', '2026-01-31 19:13:27', '2026-01-31 19:13:27'),
(1703, 'YSI', NULL, 'Parry Sound/Frying Pan Island-Sans Souci Water Aerodrome', NULL, 'CA', 'Ontario', 45.1733000, -80.1375000, 'active', '2026-01-31 19:13:28', '2026-01-31 19:13:28'),
(1704, 'YSP', 'CYSP', 'Marathon Aerodrome', NULL, 'CA', 'Ontario', 48.7553000, -86.3444000, 'active', '2026-01-31 19:13:28', '2026-01-31 19:13:28'),
(1705, 'YTA', 'CYTA', 'Pembroke Airport', NULL, 'CA', 'Ontario', 45.8644000, -77.2517000, 'active', '2026-01-31 19:13:28', '2026-01-31 19:13:28'),
(1706, 'YTL', 'CYTL', 'Big Trout Lake Airport', NULL, 'CA', 'Ontario', 53.8178000, -89.8969000, 'active', '2026-01-31 19:13:29', '2026-01-31 19:13:29'),
(1707, 'YTR', 'CYTR', 'CFB Trenton', NULL, 'CA', 'Ontario', 44.1189000, -77.5281000, 'active', '2026-01-31 19:13:29', '2026-01-31 19:13:29'),
(1708, 'YTS', 'CYTS', 'Timmins/Victor M. Power Airport', NULL, 'CA', 'Ontario', 48.5697000, -81.3767000, 'active', '2026-01-31 19:13:29', '2026-01-31 19:13:29'),
(1709, 'YTZ', 'CYTZ', 'Billy Bishop Toronto City Airport', NULL, 'CA', 'Ontario', 43.6285000, -79.3960000, 'active', '2026-01-31 19:13:30', '2026-01-31 19:13:30'),
(1710, 'YVV', 'CYVV', 'Wiarton Airport', NULL, 'CA', 'Ontario', 44.7458000, -81.1072000, 'active', '2026-01-31 19:13:30', '2026-01-31 19:13:30'),
(1711, 'YVZ', 'CYVZ', 'Deer Lake Airport', NULL, 'CA', 'Ontario', 52.6558000, -94.0614000, 'active', '2026-01-31 19:13:30', '2026-01-31 19:13:30'),
(1712, 'YWA', 'CYWA', 'Petawawa Airport', NULL, 'CA', 'Ontario', 45.9522000, -77.3192000, 'active', '2026-01-31 19:13:31', '2026-01-31 19:13:31'),
(1713, 'YWP', 'CYWP', 'Webequie Airport', NULL, 'CA', 'Ontario', 52.9594000, -87.3749000, 'active', '2026-01-31 19:13:31', '2026-01-31 19:13:31'),
(1714, 'YWR', NULL, 'White River Water Aerodrome', NULL, 'CA', 'Ontario', 48.6269000, -85.2233000, 'active', '2026-01-31 19:13:31', '2026-01-31 19:13:31'),
(1715, 'YXL', 'CYXL', 'Sioux Lookout Airport', NULL, 'CA', 'Ontario', 50.1139000, -91.9053000, 'active', '2026-01-31 19:13:32', '2026-01-31 19:13:32'),
(1716, 'YXR', 'CYXR', 'Earlton (Timiskaming Regional) Airport', NULL, 'CA', 'Ontario', 47.6974000, -79.8473000, 'active', '2026-01-31 19:13:32', '2026-01-31 19:13:32'),
(1717, 'YXU', 'CYXU', 'London International Airport', NULL, 'CA', 'Ontario', 43.0356000, -81.1539000, 'active', '2026-01-31 19:13:32', '2026-01-31 19:13:32'),
(1718, 'YXZ', 'CYXZ', 'Wawa Airport', NULL, 'CA', 'Ontario', 47.9667000, -84.7867000, 'active', '2026-01-31 19:13:33', '2026-01-31 19:13:33'),
(1719, 'YYB', 'CYYB', 'North Bay/Jack Garland Airport', NULL, 'CA', 'Ontario', 46.3636000, -79.4228000, 'active', '2026-01-31 19:13:33', '2026-01-31 19:13:33'),
(1720, 'YYU', 'CYYU', 'Kapuskasing Airport', NULL, 'CA', 'Ontario', 49.4139000, -82.4675000, 'active', '2026-01-31 19:13:33', '2026-01-31 19:13:33'),
(1721, 'YYW', 'CYYW', 'Armstrong Airport', NULL, 'CA', 'Ontario', 50.2903000, -88.9097000, 'active', '2026-01-31 19:13:34', '2026-01-31 19:13:34'),
(1722, 'YYZ', 'CYYZ', 'Toronto Pearson International Airport', NULL, 'CA', 'Ontario', 43.6797000, -79.6227000, 'active', '2026-01-31 19:13:34', '2026-01-31 19:13:34'),
(1723, 'YZE', 'CYZE', 'Gore Bay-Manitoulin Airport', NULL, 'CA', 'Ontario', 45.8853000, -82.5678000, 'active', '2026-01-31 19:13:34', '2026-01-31 19:13:34'),
(1724, 'YZR', 'CYZR', 'Sarnia Chris Hadfield Airport', NULL, 'CA', 'Ontario', 42.9994000, -82.3089000, 'active', '2026-01-31 19:13:35', '2026-01-31 19:13:35'),
(1725, 'ZKE', 'CZKE', 'Kashechewan Airport', NULL, 'CA', 'Ontario', 52.2825000, -81.6778000, 'active', '2026-01-31 19:13:35', '2026-01-31 19:13:35'),
(1726, 'ZPB', 'CZPB', 'Sachigo Lake Airport', NULL, 'CA', 'Ontario', 53.8911000, -92.1964000, 'active', '2026-01-31 19:13:35', '2026-01-31 19:13:35'),
(1727, 'ZRJ', 'CZRJ', 'Round Lake (Weagamow Lake) Airport', NULL, 'CA', 'Ontario', 52.9436000, -91.3128000, 'active', '2026-01-31 19:13:36', '2026-01-31 19:13:36'),
(1728, 'ZSJ', 'CZSJ', 'Sandy Lake Airport', NULL, 'CA', 'Ontario', 53.0642000, -93.3444000, 'active', '2026-01-31 19:13:36', '2026-01-31 19:13:36'),
(1729, 'ZUC', 'CZUC', 'Ignace Municipal Airport', NULL, 'CA', 'Ontario', 49.4297000, -91.7178000, 'active', '2026-01-31 19:13:37', '2026-01-31 19:13:37'),
(1730, 'YSU', 'CYSU', 'Summerside Airport', NULL, 'CA', 'Prince Edward Island', 46.4406000, -63.8336000, 'active', '2026-01-31 19:13:37', '2026-01-31 19:13:37'),
(1731, 'YYG', 'CYYG', 'Charlottetown Airport', NULL, 'CA', 'Prince Edward Island', 46.2900000, -63.1211000, 'active', '2026-01-31 19:13:37', '2026-01-31 19:13:37'),
(1732, 'AKV', 'CYKO', 'Akulivik Airport', NULL, 'CA', 'Quebec', 60.8186000, -78.1486000, 'active', '2026-01-31 19:13:38', '2026-01-31 19:13:38'),
(1733, 'SSQ', NULL, 'La Sarre Airport', NULL, 'CA', 'Quebec', 48.9172000, -79.1786000, 'active', '2026-01-31 19:13:38', '2026-01-31 19:13:38'),
(1734, 'XGR', 'CYLU', 'Kangiqsualujjuaq (Georges River) Airport', NULL, 'CA', 'Quebec', 58.7114000, -65.9928000, 'active', '2026-01-31 19:13:38', '2026-01-31 19:13:38'),
(1735, 'YAH', 'CYAH', 'La Grande-4 Airport', NULL, 'CA', 'Quebec', 53.7547000, -73.6753000, 'active', '2026-01-31 19:13:39', '2026-01-31 19:13:39'),
(1736, 'YAR', 'CYAD', 'La Grande-3 Airport', NULL, 'CA', 'Quebec', 53.5717000, -76.1964000, 'active', '2026-01-31 19:13:39', '2026-01-31 19:13:39'),
(1737, 'YAU', NULL, 'Kattiniq/Donaldson Airport', NULL, 'CA', 'Quebec', 61.6622000, -73.3214000, 'active', '2026-01-31 19:13:39', '2026-01-31 19:13:39'),
(1738, 'YBC', 'CYBC', 'Baie-Comeau Airport', NULL, 'CA', 'Quebec', 49.1325000, -68.2044000, 'active', '2026-01-31 19:13:40', '2026-01-31 19:13:40'),
(1739, 'YBG', 'CYBG', 'Canadian Forces Base Bagotville', NULL, 'CA', 'Quebec', 48.3306000, -70.9964000, 'active', '2026-01-31 19:13:40', '2026-01-31 19:13:40'),
(1740, 'YBJ', NULL, 'Baie-Johan-Beetz Seaplane Base', NULL, 'CA', 'Quebec', 50.2838000, -62.8063000, 'active', '2026-01-31 19:13:40', '2026-01-31 19:13:40'),
(1741, 'YBX', 'CYBX', 'Lourdes-de-Blanc-Sablon Airport', NULL, 'CA', 'Quebec', 51.4436000, -57.1853000, 'active', '2026-01-31 19:13:41', '2026-01-31 19:13:41'),
(1742, 'YDO', 'CYDO', 'Dolbeau-Saint-Felicien Airport', NULL, 'CA', 'Quebec', 48.7785000, -72.3750000, 'active', '2026-01-31 19:13:41', '2026-01-31 19:13:41'),
(1743, 'YEY', 'CYEY', 'Amos/Magny Airport', NULL, 'CA', 'Quebec', 48.5639000, -78.2497000, 'active', '2026-01-31 19:13:41', '2026-01-31 19:13:41'),
(1744, 'YFE', 'CYFE', 'Forestville Airport', NULL, 'CA', 'Quebec', 48.7461000, -69.0972000, 'active', '2026-01-31 19:13:42', '2026-01-31 19:13:42'),
(1745, 'YFG', NULL, 'Fontanges Airport', NULL, 'CA', 'Quebec', 54.5539000, -71.1733000, 'active', '2026-01-31 19:13:42', '2026-01-31 19:13:42'),
(1746, 'YGL', 'CYGL', 'La Grande Riviere Airport', NULL, 'CA', 'Quebec', 53.6253000, -77.7042000, 'active', '2026-01-31 19:13:42', '2026-01-31 19:13:42'),
(1747, 'YGP', 'CYGP', 'Michel-Pouliot Gaspe Airport', NULL, 'CA', 'Quebec', 48.7753000, -64.4786000, 'active', '2026-01-31 19:13:43', '2026-01-31 19:13:43'),
(1748, 'YGR', 'CYGR', 'Iles-de-la-Madeleine Airport', NULL, 'CA', 'Quebec', 47.4247000, -61.7781000, 'active', '2026-01-31 19:13:43', '2026-01-31 19:13:43'),
(1749, 'YGV', 'CYGV', 'Havre Saint-Pierre Airport', NULL, 'CA', 'Quebec', 50.2819000, -63.6114000, 'active', '2026-01-31 19:13:43', '2026-01-31 19:13:43'),
(1750, 'YGW', 'CYGW', 'Kuujjuarapik Airport', NULL, 'CA', 'Quebec', 55.2819000, -77.7653000, 'active', '2026-01-31 19:13:44', '2026-01-31 19:13:44'),
(1751, 'YHR', 'CYHR', 'Chevery Airport', NULL, 'CA', 'Quebec', 50.4689000, -59.6367000, 'active', '2026-01-31 19:13:44', '2026-01-31 19:13:44'),
(1752, 'YHU', 'CYHU', 'Montreal Saint-Hubert Longueuil Aiport', NULL, 'CA', 'Quebec', 45.5142000, -73.4098000, 'active', '2026-01-31 19:13:44', '2026-01-31 19:13:44'),
(1753, 'YIF', 'CYIF', 'Saint-Augustin Airport', NULL, 'CA', 'Quebec', 51.2117000, -58.6583000, 'active', '2026-01-31 19:13:45', '2026-01-31 19:13:45'),
(1754, 'YIK', 'CYIK', 'Ivujivik Airport', NULL, 'CA', 'Quebec', 62.4173000, -77.9253000, 'active', '2026-01-31 19:13:45', '2026-01-31 19:13:45'),
(1755, 'YJN', 'CYJN', 'Saint-Jean Airport', NULL, 'CA', 'Quebec', 45.2944000, -73.2811000, 'active', '2026-01-31 19:13:45', '2026-01-31 19:13:45'),
(1756, 'YKG', 'CYAS', 'Kangirsuk Airport', NULL, 'CA', 'Quebec', 60.0272000, -69.9992000, 'active', '2026-01-31 19:13:46', '2026-01-31 19:13:46'),
(1757, 'YKL', 'CYKL', 'Schefferville Airport', NULL, 'CA', 'Quebec', 54.8053000, -66.8053000, 'active', '2026-01-31 19:13:46', '2026-01-31 19:13:46'),
(1758, 'YKQ', 'CYKQ', 'Waskaganish Airport', NULL, 'CA', 'Quebec', 51.4733000, -78.7583000, 'active', '2026-01-31 19:13:46', '2026-01-31 19:13:46'),
(1759, 'YKU', NULL, 'Chisasibi Airport', NULL, 'CA', 'Quebec', 53.8056000, -78.9169000, 'active', '2026-01-31 19:13:47', '2026-01-31 19:13:47'),
(1760, 'YLP', 'CYLP', 'Mingan Airport', NULL, 'CA', 'Quebec', 50.2869000, -64.1528000, 'active', '2026-01-31 19:13:47', '2026-01-31 19:13:47'),
(1761, 'YLQ', 'CYLQ', 'La Tuque Airport', NULL, 'CA', 'Quebec', 47.4097000, -72.7889000, 'active', '2026-01-31 19:13:47', '2026-01-31 19:13:47'),
(1762, 'YLS', NULL, 'Lebel-sur-Quevillon Airport', NULL, 'CA', 'Quebec', 49.0303000, -77.0172000, 'active', '2026-01-31 19:13:48', '2026-01-31 19:13:48'),
(1763, 'YME', 'CYME', 'Matane Airport', NULL, 'CA', 'Quebec', 48.8569000, -67.4533000, 'active', '2026-01-31 19:13:48', '2026-01-31 19:13:48'),
(1764, 'YML', 'CYML', 'Charlevoix Airport', NULL, 'CA', 'Quebec', 47.5975000, -70.2239000, 'active', '2026-01-31 19:13:48', '2026-01-31 19:13:48'),
(1765, 'YMT', 'CYMT', 'Chibougamau/Chapais Airport', NULL, 'CA', 'Quebec', 49.7719000, -74.5281000, 'active', '2026-01-31 19:13:49', '2026-01-31 19:13:49'),
(1766, 'YMW', 'CYMW', 'Maniwaki Airport', NULL, 'CA', 'Quebec', 46.2728000, -75.9906000, 'active', '2026-01-31 19:13:49', '2026-01-31 19:13:49'),
(1767, 'YMX', 'CYMX', 'Montréal-Mirabel International Airport', NULL, 'CA', 'Quebec', 45.6702000, -74.0324000, 'active', '2026-01-31 19:13:49', '2026-01-31 19:13:49'),
(1768, 'YNA', 'CYNA', 'Natashquan Airport', NULL, 'CA', 'Quebec', 50.1900000, -61.7892000, 'active', '2026-01-31 19:13:50', '2026-01-31 19:13:50'),
(1769, 'YNC', 'CYNC', 'Wemindji Airport', NULL, 'CA', 'Quebec', 53.0106000, -78.8311000, 'active', '2026-01-31 19:13:50', '2026-01-31 19:13:50'),
(1770, 'YND', 'CYND', 'Gatineau-Ottawa Executive Airport', NULL, 'CA', 'Quebec', 45.5217000, -75.5636000, 'active', '2026-01-31 19:13:50', '2026-01-31 19:13:50'),
(1771, 'YNM', 'CYNM', 'Matagami Airport', NULL, 'CA', 'Quebec', 49.7617000, -77.8028000, 'active', '2026-01-31 19:13:51', '2026-01-31 19:13:51'),
(1772, 'YNS', 'CYHH', 'Nemiscau Airport', NULL, 'CA', 'Quebec', 51.6911000, -76.1356000, 'active', '2026-01-31 19:13:51', '2026-01-31 19:13:51'),
(1773, 'YOI', NULL, 'Opinaca Aerodrome', NULL, 'CA', 'Quebec', 52.2219000, -76.6119000, 'active', '2026-01-31 19:13:51', '2026-01-31 19:13:51'),
(1774, 'YPH', 'CYPH', 'Inukjuak Airport', NULL, 'CA', 'Quebec', 58.4719000, -78.0769000, 'active', '2026-01-31 19:13:52', '2026-01-31 19:13:52'),
(1775, 'YPJ', 'CYLA', 'Aupaluk Airport', NULL, 'CA', 'Quebec', 59.2967000, -69.5997000, 'active', '2026-01-31 19:13:52', '2026-01-31 19:13:52'),
(1776, 'YPN', 'CYPN', 'Port-Menier Airport', NULL, 'CA', 'Quebec', 49.8364000, -64.2886000, 'active', '2026-01-31 19:13:52', '2026-01-31 19:13:52'),
(1777, 'YPX', 'CYPX', 'Puvirnituq Airport', NULL, 'CA', 'Quebec', 60.0506000, -77.2869000, 'active', '2026-01-31 19:13:53', '2026-01-31 19:13:53'),
(1778, 'YQB', 'CYQB', 'Quebec City Jean Lesage International Airport', NULL, 'CA', 'Quebec', 46.7911000, -71.3933000, 'active', '2026-01-31 19:13:53', '2026-01-31 19:13:53'),
(1779, 'YQC', 'CYHA', 'Quaqtaq Airport', NULL, 'CA', 'Quebec', 61.0464000, -69.6178000, 'active', '2026-01-31 19:13:53', '2026-01-31 19:13:53'),
(1780, 'YRI', 'CYRI', 'Riviere-du-Loup Airport', NULL, 'CA', 'Quebec', 47.7644000, -69.5847000, 'active', '2026-01-31 19:13:54', '2026-01-31 19:13:54'),
(1781, 'YRJ', 'CYRJ', 'Roberval Airport', NULL, 'CA', 'Quebec', 48.5200000, -72.2656000, 'active', '2026-01-31 19:13:54', '2026-01-31 19:13:54'),
(1782, 'YRQ', 'CYRQ', 'Trois-Rivieres Airport', NULL, 'CA', 'Quebec', 46.3528000, -72.6794000, 'active', '2026-01-31 19:13:54', '2026-01-31 19:13:54'),
(1783, 'YSC', 'CYSC', 'Sherbrooke Airport', NULL, 'CA', 'Quebec', 45.4386000, -71.6914000, 'active', '2026-01-31 19:13:55', '2026-01-31 19:13:55'),
(1784, 'YTF', 'CYTF', 'Alma Airport', NULL, 'CA', 'Quebec', 48.5089000, -71.6419000, 'active', '2026-01-31 19:13:55', '2026-01-31 19:13:55'),
(1785, 'YTM', 'CYFJ', 'Mont Tremblant International Airport', NULL, 'CA', 'Quebec', 46.4094000, -74.7800000, 'active', '2026-01-31 19:13:55', '2026-01-31 19:13:55'),
(1786, 'YTQ', 'CYTQ', 'Tasiujaq Airport', NULL, 'CA', 'Quebec', 58.6678000, -69.9558000, 'active', '2026-01-31 19:13:56', '2026-01-31 19:13:56'),
(1787, 'YUD', 'CYMU', 'Umiujaq Airport', NULL, 'CA', 'Quebec', 56.5361000, -76.5183000, 'active', '2026-01-31 19:13:56', '2026-01-31 19:13:56'),
(1788, 'YUL', 'CYUL', 'Montréal-Pierre Elliott Trudeau International Airport', NULL, 'CA', 'Quebec', 45.4657000, -73.7455000, 'active', '2026-01-31 19:13:56', '2026-01-31 19:13:56'),
(1789, 'YUY', 'CYUY', 'Rouyn-Noranda Airport', NULL, 'CA', 'Quebec', 48.2061000, -78.8356000, 'active', '2026-01-31 19:13:57', '2026-01-31 19:13:57'),
(1790, 'YVB', 'CYVB', 'Bonaventure Airport', NULL, 'CA', 'Quebec', 48.0711000, -65.4603000, 'active', '2026-01-31 19:13:57', '2026-01-31 19:13:57'),
(1791, 'YVO', 'CYVO', 'Val-d\'Or Airport', NULL, 'CA', 'Quebec', 48.0533000, -77.7828000, 'active', '2026-01-31 19:13:57', '2026-01-31 19:13:57'),
(1792, 'YVP', 'CYVP', 'Kuujjuaq Airport', NULL, 'CA', 'Quebec', 58.0961000, -68.4269000, 'active', '2026-01-31 19:13:58', '2026-01-31 19:13:58'),
(1793, 'YWB', 'CYKG', 'Kangiqsujuaq (Wakeham Bay) Airport', NULL, 'CA', 'Quebec', 61.5886000, -71.9294000, 'active', '2026-01-31 19:13:58', '2026-01-31 19:13:58'),
(1794, 'YWQ', NULL, 'Chutes-des-Passes/Lac Margane Water Aerodrome', NULL, 'CA', 'Quebec', 49.9434000, -71.1380000, 'active', '2026-01-31 19:13:58', '2026-01-31 19:13:58'),
(1795, 'YXK', 'CYXK', 'Rimouski Airport', NULL, 'CA', 'Quebec', 48.4781000, -68.4969000, 'active', '2026-01-31 19:13:59', '2026-01-31 19:13:59'),
(1796, 'YYY', 'CYYY', 'Mont-Joli Airport', NULL, 'CA', 'Quebec', 48.6086000, -68.2081000, 'active', '2026-01-31 19:13:59', '2026-01-31 19:13:59'),
(1797, 'YZG', 'CYZG', 'Salluit Airport', NULL, 'CA', 'Quebec', 62.1794000, -75.6672000, 'active', '2026-01-31 19:13:59', '2026-01-31 19:13:59'),
(1798, 'YZV', 'CYZV', 'Sept-Iles Airport', NULL, 'CA', 'Quebec', 50.2233000, -66.2656000, 'active', '2026-01-31 19:14:00', '2026-01-31 19:14:00'),
(1799, 'ZBM', 'CZBM', 'Roland-Desourdy Airport', NULL, 'CA', 'Quebec', 45.2908000, -72.7414000, 'active', '2026-01-31 19:14:00', '2026-01-31 19:14:00'),
(1800, 'ZEM', 'CZEM', 'Eastmain River Airport', NULL, 'CA', 'Quebec', 52.2264000, -78.5225000, 'active', '2026-01-31 19:14:00', '2026-01-31 19:14:00'),
(1801, 'ZGS', NULL, 'La Romaine Airport', NULL, 'CA', 'Quebec', 50.2597000, -60.6794000, 'active', '2026-01-31 19:14:01', '2026-01-31 19:14:01'),
(1802, 'ZKG', NULL, 'Kegaska Airport', NULL, 'CA', 'Quebec', 50.1958000, -61.2658000, 'active', '2026-01-31 19:14:01', '2026-01-31 19:14:01'),
(1803, 'ZLT', NULL, 'La Tabatiere Airport', NULL, 'CA', 'Quebec', 50.8308000, -58.9756000, 'active', '2026-01-31 19:14:01', '2026-01-31 19:14:01'),
(1804, 'ZTB', NULL, 'Tete-a-la-Baleine Airport', NULL, 'CA', 'Quebec', 50.6744000, -59.3836000, 'active', '2026-01-31 19:14:02', '2026-01-31 19:14:02'),
(1805, 'XCL', NULL, 'Cluff Lake Airport', NULL, 'CA', 'Saskatchewan', 58.3911000, -109.5160000, 'active', '2026-01-31 19:14:02', '2026-01-31 19:14:02'),
(1806, 'YBE', 'CYBE', 'Uranium City Airport', NULL, 'CA', 'Saskatchewan', 59.5614000, -108.4810000, 'active', '2026-01-31 19:14:02', '2026-01-31 19:14:02'),
(1807, 'YDJ', NULL, 'Hatchet Lake Airport', NULL, 'CA', 'Saskatchewan', 58.6625000, -103.5380000, 'active', '2026-01-31 19:14:03', '2026-01-31 19:14:03'),
(1808, 'YEN', 'CYEN', 'Estevan Regional Aerodrome', NULL, 'CA', 'Saskatchewan', 49.2103000, -102.9660000, 'active', '2026-01-31 19:14:03', '2026-01-31 19:14:03'),
(1809, 'YHB', 'CYHB', 'Hudson Bay Airport', NULL, 'CA', 'Saskatchewan', 52.8167000, -102.3110000, 'active', '2026-01-31 19:14:03', '2026-01-31 19:14:03'),
(1810, 'YKC', 'CYKC', 'Collins Bay Airport', NULL, 'CA', 'Saskatchewan', 58.2361000, -103.6780000, 'active', '2026-01-31 19:14:04', '2026-01-31 19:14:04'),
(1811, 'YKJ', 'CYKJ', 'Key Lake Airport', NULL, 'CA', 'Saskatchewan', 57.2561000, -105.6180000, 'active', '2026-01-31 19:14:04', '2026-01-31 19:14:04'),
(1812, 'YKY', 'CYKY', 'Kindersley Regional Airport', NULL, 'CA', 'Saskatchewan', 51.5175000, -109.1810000, 'active', '2026-01-31 19:14:04', '2026-01-31 19:14:04'),
(1813, 'YLJ', 'CYLJ', 'Meadow Lake Airport', NULL, 'CA', 'Saskatchewan', 54.1253000, -108.5230000, 'active', '2026-01-31 19:14:05', '2026-01-31 19:14:05'),
(1814, 'YMJ', 'CYMJ', 'CFB Moose Jaw (C.M. McEwen Airport)', NULL, 'CA', 'Saskatchewan', 50.3303000, -105.5590000, 'active', '2026-01-31 19:14:05', '2026-01-31 19:14:05'),
(1815, 'YNL', 'CYNL', 'Points North Landing Airport', NULL, 'CA', 'Saskatchewan', 58.2767000, -104.0820000, 'active', '2026-01-31 19:14:05', '2026-01-31 19:14:05'),
(1816, 'YPA', 'CYPA', 'Prince Albert (Glass Field) Airport', NULL, 'CA', 'Saskatchewan', 53.2142000, -105.6730000, 'active', '2026-01-31 19:14:06', '2026-01-31 19:14:06'),
(1817, 'YQR', 'CYQR', 'Regina International Airport', NULL, 'CA', 'Saskatchewan', 50.4319000, -104.6660000, 'active', '2026-01-31 19:14:06', '2026-01-31 19:14:06'),
(1818, 'YQV', 'CYQV', 'Yorkton Municipal Airport', NULL, 'CA', 'Saskatchewan', 51.2647000, -102.4620000, 'active', '2026-01-31 19:14:07', '2026-01-31 19:14:07'),
(1819, 'YQW', 'CYQW', 'North Battleford Airport (Cameron McIntosh Airport)', NULL, 'CA', 'Saskatchewan', 52.7692000, -108.2440000, 'active', '2026-01-31 19:14:07', '2026-01-31 19:14:07'),
(1820, 'YSF', 'CYSF', 'Stony Rapids Airport', NULL, 'CA', 'Saskatchewan', 59.2503000, -105.8410000, 'active', '2026-01-31 19:14:07', '2026-01-31 19:14:07'),
(1821, 'YTT', NULL, 'Tisdale Airport', NULL, 'CA', 'Saskatchewan', 52.8367000, -104.0670000, 'active', '2026-01-31 19:14:08', '2026-01-31 19:14:08'),
(1822, 'YVC', 'CYVC', 'La Ronge (Barber Field) Airport', NULL, 'CA', 'Saskatchewan', 55.1514000, -105.2620000, 'active', '2026-01-31 19:14:08', '2026-01-31 19:14:08'),
(1823, 'YVT', 'CYVT', 'Buffalo Narrows Airport', NULL, 'CA', 'Saskatchewan', 55.8419000, -108.4180000, 'active', '2026-01-31 19:14:08', '2026-01-31 19:14:08'),
(1824, 'YXE', 'CYXE', 'Saskatoon John G. Diefenbaker International Airport', NULL, 'CA', 'Saskatchewan', 52.1708000, -106.7000000, 'active', '2026-01-31 19:14:09', '2026-01-31 19:14:09'),
(1825, 'YYN', 'CYYN', 'Swift Current Airport', NULL, 'CA', 'Saskatchewan', 50.2919000, -107.6910000, 'active', '2026-01-31 19:14:09', '2026-01-31 19:14:09'),
(1826, 'ZFD', 'CZFD', 'Fond-du-Lac Airport', NULL, 'CA', 'Saskatchewan', 59.3344000, -107.1820000, 'active', '2026-01-31 19:14:09', '2026-01-31 19:14:09'),
(1827, 'ZPO', 'CZPO', 'Pinehouse Lake Airport', NULL, 'CA', 'Saskatchewan', 55.5281000, -106.5820000, 'active', '2026-01-31 19:14:10', '2026-01-31 19:14:10'),
(1828, 'ZWL', 'CZWL', 'Wollaston Lake Airport', NULL, 'CA', 'Saskatchewan', 58.1069000, -103.1720000, 'active', '2026-01-31 19:14:10', '2026-01-31 19:14:10'),
(1829, 'XMP', NULL, 'Macmillan Pass Airport', NULL, 'CA', 'Yukon', 63.1811000, -130.2020000, 'active', '2026-01-31 19:14:10', '2026-01-31 19:14:10'),
(1830, 'XRR', 'CYDM', 'Ross River Airport', NULL, 'CA', 'Yukon', 61.9706000, -132.4230000, 'active', '2026-01-31 19:14:11', '2026-01-31 19:14:11'),
(1831, 'YDA', 'CYDA', 'Dawson City Airport', NULL, 'CA', 'Yukon', 64.0431000, -139.1280000, 'active', '2026-01-31 19:14:11', '2026-01-31 19:14:11'),
(1832, 'YDB', 'CYDB', 'Burwash Airport', NULL, 'CA', 'Yukon', 61.3711000, -139.0410000, 'active', '2026-01-31 19:14:11', '2026-01-31 19:14:11'),
(1833, 'YHT', 'CYHT', 'Haines Junction Airport', NULL, 'CA', 'Yukon', 60.7892000, -137.5460000, 'active', '2026-01-31 19:14:12', '2026-01-31 19:14:12'),
(1834, 'YLM', NULL, 'Clinton Creek Airport', NULL, 'CA', 'Yukon', 64.4755000, -140.7420000, 'active', '2026-01-31 19:14:12', '2026-01-31 19:14:12'),
(1835, 'YMA', 'CYMA', 'Mayo Airport', NULL, 'CA', 'Yukon', 63.6164000, -135.8680000, 'active', '2026-01-31 19:14:12', '2026-01-31 19:14:12'),
(1836, 'YOC', 'CYOC', 'Old Crow Airport', NULL, 'CA', 'Yukon', 67.5706000, -139.8390000, 'active', '2026-01-31 19:14:13', '2026-01-31 19:14:13'),
(1837, 'YQH', 'CYQH', 'Watson Lake Airport', NULL, 'CA', 'Yukon', 60.1164000, -128.8220000, 'active', '2026-01-31 19:14:13', '2026-01-31 19:14:13'),
(1838, 'YXQ', 'CYXQ', 'Beaver Creek Airport', NULL, 'CA', 'Yukon', 62.4103000, -140.8670000, 'active', '2026-01-31 19:14:13', '2026-01-31 19:14:13'),
(1839, 'YXY', 'CYXY', 'Erik Nielsen Whitehorse International Airport', NULL, 'CA', 'Yukon', 60.7096000, -135.0670000, 'active', '2026-01-31 19:14:14', '2026-01-31 19:14:14'),
(1840, 'YZW', 'CYZW', 'Teslin Airport', NULL, 'CA', 'Yukon', 60.1728000, -132.7430000, 'active', '2026-01-31 19:14:14', '2026-01-31 19:14:14'),
(1841, 'ZFA', 'CZFA', 'Faro Airport (Yukon)', NULL, 'CA', 'Yukon', 62.2075000, -133.3760000, 'active', '2026-01-31 19:14:14', '2026-01-31 19:14:14'),
(1842, 'CCK', 'YPCC', 'Cocos (Keeling) Islands Airport', NULL, 'CC', 'Cocos (Keeling) Islands', -12.1886000, 96.8306000, 'active', '2026-01-31 19:14:15', '2026-01-31 19:14:15'),
(1843, 'BZU', 'FZKJ', 'Buta Zega Airport', NULL, 'CD', 'Bas-Uele', 2.8183500, 24.7937000, 'active', '2026-01-31 19:14:15', '2026-01-31 19:14:15'),
(1844, 'BDT', 'FZFD', 'Gbadolite Airport', NULL, 'CD', 'Equateur', 4.2532100, 20.9753000, 'active', '2026-01-31 19:14:15', '2026-01-31 19:14:15'),
(1845, 'BSU', 'FZEN', 'Basankusu Airport', NULL, 'CD', 'Equateur', 1.2247200, 19.7889000, 'active', '2026-01-31 19:14:16', '2026-01-31 19:14:16'),
(1846, 'MDK', 'FZEA', 'Mbandaka Airport', NULL, 'CD', 'Equateur', 0.0226000, 18.2887000, 'active', '2026-01-31 19:14:16', '2026-01-31 19:14:16'),
(1847, 'FBM', 'FZQA', 'Lubumbashi International Airport', NULL, 'CD', 'Haut-Katanga', -11.5913000, 27.5309000, 'active', '2026-01-31 19:14:16', '2026-01-31 19:14:16'),
(1848, 'KAP', 'FZSK', 'Kapanga Airport', NULL, 'CD', 'Haut-Katanga', -8.3500000, 22.5830000, 'active', '2026-01-31 19:14:17', '2026-01-31 19:14:17'),
(1849, 'KEC', 'FZQG', 'Kasenga Airport', NULL, 'CD', 'Haut-Katanga', -10.3500000, 28.6330000, 'active', '2026-01-31 19:14:17', '2026-01-31 19:14:17'),
(1850, 'KIL', NULL, 'Kilwa Airport', NULL, 'CD', 'Haut-Katanga', -9.2886000, 28.3269000, 'active', '2026-01-31 19:14:17', '2026-01-31 19:14:17'),
(1851, 'KNM', 'FZTK', 'Kaniama Airport', NULL, 'CD', 'Haut-Katanga', -7.5830000, 24.1500000, 'active', '2026-01-31 19:14:18', '2026-01-31 19:14:18'),
(1852, 'PWO', 'FZQC', 'Pweto Airport', NULL, 'CD', 'Haut-Katanga', -8.4670000, 28.8830000, 'active', '2026-01-31 19:14:18', '2026-01-31 19:14:18'),
(1853, 'BUX', 'FZKA', 'Bunia Airport', NULL, 'CD', 'Ituri', 1.5657200, 30.2208000, 'active', '2026-01-31 19:14:18', '2026-01-31 19:14:18'),
(1854, 'GDJ', 'FZWC', 'Gandajika Airport', NULL, 'CD', 'Kasai Oriental', -6.7330000, 23.9500000, 'active', '2026-01-31 19:14:19', '2026-01-31 19:14:19'),
(1855, 'KBN', 'FZWT', 'Tunta Airport', NULL, 'CD', 'Kasai Oriental', -6.1330000, 24.4830000, 'active', '2026-01-31 19:14:19', '2026-01-31 19:14:19'),
(1856, 'LBO', 'FZVI', 'Lusambo Airport', NULL, 'CD', 'Kasai Oriental', -4.9616700, 23.3783000, 'active', '2026-01-31 19:14:19', '2026-01-31 19:14:19'),
(1857, 'LJA', 'FZVA', 'Lodja Airport', NULL, 'CD', 'Kasai Oriental', -3.4170000, 23.4500000, 'active', '2026-01-31 19:14:20', '2026-01-31 19:14:20'),
(1858, 'MJM', 'FZWA', 'Mbuji Mayi Airport', NULL, 'CD', 'Kasai Oriental', -6.1212400, 23.5690000, 'active', '2026-01-31 19:14:20', '2026-01-31 19:14:20'),
(1859, 'BAN', 'FZVR', 'Basongo Airport', NULL, 'CD', 'Kasai', -4.3158000, 20.4149000, 'active', '2026-01-31 19:14:20', '2026-01-31 19:14:20'),
(1860, 'KGA', 'FZUA', 'Kananga Airport', NULL, 'CD', 'Kasai', -5.9000500, 22.4692000, 'active', '2026-01-31 19:14:21', '2026-01-31 19:14:21'),
(1861, 'LZA', 'FZUG', 'Luiza Airport', NULL, 'CD', 'Kasai', -7.1830000, 22.4000000, 'active', '2026-01-31 19:14:21', '2026-01-31 19:14:21'),
(1862, 'MEW', 'FZVM', 'Mweka Airport', NULL, 'CD', 'Kasai', -4.8500000, 21.5500000, 'active', '2026-01-31 19:14:21', '2026-01-31 19:14:21'),
(1863, 'PFR', 'FZVS', 'Ilebo Airport', NULL, 'CD', 'Kasai', -4.3299200, 20.5901000, 'active', '2026-01-31 19:14:22', '2026-01-31 19:14:22'),
(1864, 'TSH', 'FZUK', 'Tshikapa Airport', NULL, 'CD', 'Kasai', -6.4383300, 20.7947000, 'active', '2026-01-31 19:14:22', '2026-01-31 19:14:22'),
(1865, 'FIH', 'FZAA', 'N\'djili Airport', NULL, 'CD', 'Kinshasa', -4.3857500, 15.4446000, 'active', '2026-01-31 19:14:22', '2026-01-31 19:14:22'),
(1866, 'NLO', 'FZAB', 'N\'Dolo Airport', NULL, 'CD', 'Kinshasa', -4.3266600, 15.3275000, 'active', '2026-01-31 19:14:23', '2026-01-31 19:14:23'),
(1867, 'BOA', 'FZAJ', 'Boma Airport', NULL, 'CD', 'Kongo Central', -5.8540000, 13.0640000, 'active', '2026-01-31 19:14:23', '2026-01-31 19:14:23'),
(1868, 'LZI', 'FZAL', 'Luozi Airport', NULL, 'CD', 'Kongo Central', -4.9500000, 14.1330000, 'active', '2026-01-31 19:14:23', '2026-01-31 19:14:23'),
(1869, 'MAT', 'FZAM', 'Matadi Tshimpi Airport', NULL, 'CD', 'Kongo Central', -5.7996100, 13.4404000, 'active', '2026-01-31 19:14:24', '2026-01-31 19:14:24'),
(1870, 'MNB', 'FZAG', 'Muanda Airport (Moanda Airport)', NULL, 'CD', 'Kongo Central', -5.9308600, 12.3518000, 'active', '2026-01-31 19:14:24', '2026-01-31 19:14:24'),
(1871, 'NKL', 'FZAR', 'Nkolo-Fuma Airport', NULL, 'CD', 'Kongo Central', -5.4210000, 14.8169000, 'active', '2026-01-31 19:14:24', '2026-01-31 19:14:24'),
(1872, 'KWZ', 'FZQM', 'Kolwezi Airport', NULL, 'CD', 'Lualaba', -10.7659000, 25.5057000, 'active', '2026-01-31 19:14:25', '2026-01-31 19:14:25'),
(1873, 'FDU', 'FZBO', 'Bandundu Airport', NULL, 'CD', 'Mai-Ndombe', -3.3113200, 17.3817000, 'active', '2026-01-31 19:14:25', '2026-01-31 19:14:25'),
(1874, 'IDF', 'FZCB', 'Idiofa Airport', NULL, 'CD', 'Mai-Ndombe', -5.0000000, 19.6000000, 'active', '2026-01-31 19:14:25', '2026-01-31 19:14:25'),
(1875, 'INO', 'FZBA', 'Inongo Airport', NULL, 'CD', 'Mai-Ndombe', -1.9472200, 18.2858000, 'active', '2026-01-31 19:14:26', '2026-01-31 19:14:26'),
(1876, 'KGN', 'FZOK', 'Kasongo Lunda Airport', NULL, 'CD', 'Mai-Ndombe', -4.5330000, 26.6170000, 'active', '2026-01-31 19:14:26', '2026-01-31 19:14:26'),
(1877, 'KKW', 'FZCA', 'Kikwit Airport', NULL, 'CD', 'Mai-Ndombe', -5.0357700, 18.7856000, 'active', '2026-01-31 19:14:26', '2026-01-31 19:14:26'),
(1878, 'KRZ', 'FZBT', 'Basango Mboliasa Airport', NULL, 'CD', 'Mai-Ndombe', -1.4350000, 19.0240000, 'active', '2026-01-31 19:14:27', '2026-01-31 19:14:27'),
(1879, 'LUS', 'FZCE', 'Lusanga Airport', NULL, 'CD', 'Mai-Ndombe', -4.8000000, 18.7170000, 'active', '2026-01-31 19:14:27', '2026-01-31 19:14:27'),
(1880, 'MSM', 'FZCV', 'Masi-Manimba Airport', NULL, 'CD', 'Mai-Ndombe', -4.7830000, 17.8500000, 'active', '2026-01-31 19:14:27', '2026-01-31 19:14:27'),
(1881, 'NIO', 'FZBI', 'Nioki Airport', NULL, 'CD', 'Mai-Ndombe', -2.7175000, 17.6847000, 'active', '2026-01-31 19:14:28', '2026-01-31 19:14:28'),
(1882, 'KLY', 'FZOC', 'Kamisuku Airport', NULL, 'CD', 'Maniema', -2.5780000, 26.7340000, 'active', '2026-01-31 19:14:28', '2026-01-31 19:14:28'),
(1883, 'KND', 'FZOA', 'Kindu Airport', NULL, 'CD', 'Maniema', -2.9191800, 25.9154000, 'active', '2026-01-31 19:14:28', '2026-01-31 19:14:28'),
(1884, 'PUN', 'FZOP', 'Punia Airport', NULL, 'CD', 'Maniema', -1.3670000, 26.3330000, 'active', '2026-01-31 19:14:29', '2026-01-31 19:14:29'),
(1885, 'BMB', 'FZFU', 'Bumba Airport', NULL, 'CD', 'Mongala', 2.1827800, 22.4817000, 'active', '2026-01-31 19:14:29', '2026-01-31 19:14:29'),
(1886, 'LIQ', 'FZGA', 'Lisala Airport', NULL, 'CD', 'Mongala', 2.1706600, 21.4969000, 'active', '2026-01-31 19:14:29', '2026-01-31 19:14:29'),
(1887, 'BNC', 'FZNP', 'Beni Airport', NULL, 'CD', 'Nord-Kivu', 0.5750000, 29.4739000, 'active', '2026-01-31 19:14:30', '2026-01-31 19:14:30'),
(1888, 'GOM', 'FZNA', 'Goma International Airport', NULL, 'CD', 'Nord-Kivu', -1.6708100, 29.2385000, 'active', '2026-01-31 19:14:30', '2026-01-31 19:14:30'),
(1889, 'IRP', 'FZJH', 'Matari Airport', NULL, 'CD', 'Nord-Kivu', 2.8276100, 27.5883000, 'active', '2026-01-31 19:14:30', '2026-01-31 19:14:30'),
(1890, 'RUE', NULL, 'Butembo Airport', NULL, 'CD', 'Nord-Kivu', 0.1171420, 29.3130000, 'active', '2026-01-31 19:14:31', '2026-01-31 19:14:31'),
(1891, 'KLI', 'FZFP', 'Kotakoli Air Base', NULL, 'CD', 'Nord-Ubangi', 4.1576400, 21.6509000, 'active', '2026-01-31 19:14:31', '2026-01-31 19:14:31'),
(1892, 'IKL', 'FZGV', 'Ikela Airport', NULL, 'CD', 'Sankuru', -1.0481100, 23.3725000, 'active', '2026-01-31 19:14:31', '2026-01-31 19:14:31'),
(1893, 'BKY', 'FZMA', 'Kavumu Airport', NULL, 'CD', 'Sud-Kivu', -2.3089800, 28.8088000, 'active', '2026-01-31 19:14:32', '2026-01-31 19:14:32'),
(1894, 'GMA', 'FZFK', 'Gemena Airport', NULL, 'CD', 'Sud-Ubangi', 3.2353700, 19.7713000, 'active', '2026-01-31 19:14:32', '2026-01-31 19:14:32'),
(1895, 'LIE', 'FZFA', 'Libenge Airport', NULL, 'CD', 'Sud-Ubangi', 3.6330000, 18.6330000, 'active', '2026-01-31 19:14:32', '2026-01-31 19:14:32'),
(1896, 'BDV', 'FZRB', 'Moba Airport', NULL, 'CD', 'Tanganyika', -7.0670000, 29.7830000, 'active', '2026-01-31 19:14:33', '2026-01-31 19:14:33'),
(1897, 'FMI', 'FZRF', 'Kalemie Airport', NULL, 'CD', 'Tanganyika', -5.8755600, 29.2500000, 'active', '2026-01-31 19:14:33', '2026-01-31 19:14:33'),
(1898, 'KBO', 'FZRM', 'Kabalo Airport', NULL, 'CD', 'Tanganyika', -6.0830000, 26.9170000, 'active', '2026-01-31 19:14:33', '2026-01-31 19:14:33'),
(1899, 'KOO', 'FZRQ', 'Kongolo Airport', NULL, 'CD', 'Tanganyika', -5.3944400, 26.9900000, 'active', '2026-01-31 19:14:34', '2026-01-31 19:14:34'),
(1900, 'MNO', 'FZRA', 'Manono Airport', NULL, 'CD', 'Tanganyika', -7.2888900, 27.3944000, 'active', '2026-01-31 19:14:34', '2026-01-31 19:14:34'),
(1901, 'FKI', 'FZIC', 'Bangoka International Airport', NULL, 'CD', 'Tshopo', 0.4816390, 25.3380000, 'active', '2026-01-31 19:14:34', '2026-01-31 19:14:34'),
(1902, 'YAN', 'FZIR', 'Yangambi Airport', NULL, 'CD', 'Tshopo', 0.7830000, 24.4670000, 'active', '2026-01-31 19:14:35', '2026-01-31 19:14:35'),
(1903, 'BNB', 'FZGN', 'Boende Airport', NULL, 'CD', 'Tshuapa', -0.2170000, 20.8500000, 'active', '2026-01-31 19:14:35', '2026-01-31 19:14:35'),
(1904, 'GDA', NULL, 'Gounda Airport', NULL, 'CF', 'Bamingui-Bangoran', 9.3167000, 21.1850000, 'active', '2026-01-31 19:14:35', '2026-01-31 19:14:35'),
(1905, 'KOL', NULL, 'Koumala Airport', NULL, 'CF', 'Bamingui-Bangoran', 8.4965000, 21.2565000, 'active', '2026-01-31 19:14:36', '2026-01-31 19:14:36'),
(1906, 'NDL', 'FEFN', 'N\'Dele Airport', NULL, 'CF', 'Bamingui-Bangoran', 8.4272100, 20.6352000, 'active', '2026-01-31 19:14:36', '2026-01-31 19:14:36'),
(1907, 'BGF', 'FEFF', 'Bangui M\'Poko International Airport', NULL, 'CF', 'Bangui', 4.3984800, 18.5188000, 'active', '2026-01-31 19:14:36', '2026-01-31 19:14:36'),
(1908, 'IMO', 'FEFZ', 'Zemio Airport', NULL, 'CF', 'Haut-Mbomou', 5.0500000, 25.1500000, 'active', '2026-01-31 19:14:37', '2026-01-31 19:14:37'),
(1909, 'MKI', 'FEGE', 'M\'Boki Airport', NULL, 'CF', 'Haut-Mbomou', 5.3330100, 25.9319000, 'active', '2026-01-31 19:14:37', '2026-01-31 19:14:37'),
(1910, 'AIG', 'FEFY', 'Yalinga Airport', NULL, 'CF', 'Haute-Kotto', 6.5200000, 23.2600000, 'active', '2026-01-31 19:14:37', '2026-01-31 19:14:37'),
(1911, 'BIV', 'FEFR', 'Bria Airport', NULL, 'CF', 'Haute-Kotto', 6.5277800, 21.9894000, 'active', '2026-01-31 19:14:38', '2026-01-31 19:14:38'),
(1912, 'KWD', NULL, 'Kavadja Airport', NULL, 'CF', 'Haute-Kotto', -1.9500000, 124.9670000, 'active', '2026-01-31 19:14:38', '2026-01-31 19:14:38'),
(1913, 'ODA', 'FEFW', 'Ouadda Airport', NULL, 'CF', 'Haute-Kotto', 8.0105600, 22.3986000, 'active', '2026-01-31 19:14:38', '2026-01-31 19:14:38'),
(1914, 'BBT', 'FEFT', 'Berberati Airport', NULL, 'CF', 'Mambere-Kadei', 4.2215800, 15.7864000, 'active', '2026-01-31 19:14:39', '2026-01-31 19:14:39'),
(1915, 'CRF', 'FEFC', 'Carnot Airport', NULL, 'CF', 'Mambere-Kadei', 4.9370000, 15.8940000, 'active', '2026-01-31 19:14:39', '2026-01-31 19:14:39'),
(1916, 'BGU', 'FEFG', 'Bangassou Airport', NULL, 'CF', 'Mbomou', 4.7850000, 22.7810000, 'active', '2026-01-31 19:14:39', '2026-01-31 19:14:39'),
(1917, 'BMF', 'FEGM', 'Bakouma Airport', NULL, 'CF', 'Mbomou', 5.6940000, 22.8010000, 'active', '2026-01-31 19:14:40', '2026-01-31 19:14:40'),
(1918, 'RFA', 'FEGR', 'Rafai Airport', NULL, 'CF', 'Mbomou', 4.9886100, 23.9278000, 'active', '2026-01-31 19:14:40', '2026-01-31 19:14:40'),
(1919, 'BOP', 'FEFO', 'Bouar Airport', NULL, 'CF', 'Nana-Mambere', 5.9580000, 15.6370000, 'active', '2026-01-31 19:14:40', '2026-01-31 19:14:40'),
(1920, 'BBY', 'FEFM', 'Bambari Airport', NULL, 'CF', 'Ouaka', 5.8469400, 20.6475000, 'active', '2026-01-31 19:14:41', '2026-01-31 19:14:41'),
(1921, 'BCF', 'FEGU', 'Bouca Airport', NULL, 'CF', 'Ouham', 6.5170000, 18.2670000, 'active', '2026-01-31 19:14:41', '2026-01-31 19:14:41'),
(1922, 'BSN', 'FEFS', 'Bossangoa Airport', NULL, 'CF', 'Ouham', 6.4920000, 17.4290000, 'active', '2026-01-31 19:14:41', '2026-01-31 19:14:41'),
(1923, 'BTG', 'FEGF', 'Batangafo Airport', NULL, 'CF', 'Ouham', 7.3141100, 18.3088000, 'active', '2026-01-31 19:14:42', '2026-01-31 19:14:42'),
(1924, 'BOZ', 'FEGZ', 'Bozoum Airport', NULL, 'CF', 'Ouham-Pende', 6.3441700, 16.3219000, 'active', '2026-01-31 19:14:42', '2026-01-31 19:14:42'),
(1925, 'GDI', NULL, 'Gordil Airport', NULL, 'CF', 'Vakaga', 9.5811200, 21.7282000, 'active', '2026-01-31 19:14:42', '2026-01-31 19:14:42'),
(1926, 'IRO', 'FEFI', 'Birao Airport', NULL, 'CF', 'Vakaga', 10.2364000, 22.7169000, 'active', '2026-01-31 19:14:43', '2026-01-31 19:14:43'),
(1927, 'ODJ', 'FEGO', 'Ouanda Djalle Airport', NULL, 'CF', 'Vakaga', 8.9000000, 22.7830000, 'active', '2026-01-31 19:14:43', '2026-01-31 19:14:43'),
(1928, 'MUY', 'FCBM', 'Mouyondzi Airport', NULL, 'CG', 'Bouenza', -4.0148700, 13.9661000, 'active', '2026-01-31 19:14:43', '2026-01-31 19:14:43'),
(1929, 'NKY', 'FCBY', 'Yokangassi Airport', NULL, 'CG', 'Bouenza', -4.2230800, 13.2863000, 'active', '2026-01-31 19:14:44', '2026-01-31 19:14:44'),
(1930, 'ANJ', 'FCBZ', 'Zanaga Airport', NULL, 'CG', 'Brazzaville', -2.8500000, 13.8170000, 'active', '2026-01-31 19:14:44', '2026-01-31 19:14:44'),
(1931, 'BZV', 'FCBB', 'Maya-Maya Airport', NULL, 'CG', 'Brazzaville', -4.2517000, 15.2530000, 'active', '2026-01-31 19:14:44', '2026-01-31 19:14:44'),
(1932, 'BOE', 'FCOB', 'Boundji Airport', NULL, 'CG', 'Cuvette', -1.0330000, 15.3830000, 'active', '2026-01-31 19:14:45', '2026-01-31 19:14:45'),
(1933, 'FTX', 'FCOO', 'Owando Airport', NULL, 'CG', 'Cuvette', -0.5313500, 15.9501000, 'active', '2026-01-31 19:14:45', '2026-01-31 19:14:45');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(1934, 'MKJ', 'FCOM', 'Makoua Airport', NULL, 'CG', 'Cuvette', -0.0170000, 15.5830000, 'active', '2026-01-31 19:14:46', '2026-01-31 19:14:46'),
(1935, 'OKG', NULL, 'Okoyo Airport', NULL, 'CG', 'Cuvette', -1.4483300, 15.0733000, 'active', '2026-01-31 19:14:46', '2026-01-31 19:14:46'),
(1936, 'OLL', NULL, 'Oyo Ollombo Airport', NULL, 'CG', 'Cuvette', -1.2266700, 15.9100000, 'active', '2026-01-31 19:14:46', '2026-01-31 19:14:46'),
(1937, 'EWO', 'FCOE', 'Ewo Airport', NULL, 'CG', 'Cuvette-Ouest', -0.8830000, 14.8000000, 'active', '2026-01-31 19:14:47', '2026-01-31 19:14:47'),
(1938, 'KEE', 'FCOK', 'Kelle Airport', NULL, 'CG', 'Cuvette-Ouest', -0.0830000, 14.5330000, 'active', '2026-01-31 19:14:47', '2026-01-31 19:14:47'),
(1939, 'SIB', 'FCBS', 'Sibiti Airport', NULL, 'CG', 'Lekoumou', -3.6830000, 13.3500000, 'active', '2026-01-31 19:14:47', '2026-01-31 19:14:47'),
(1940, 'BTB', 'FCOT', 'Betou Airport', NULL, 'CG', 'Likouala', 3.0500000, 18.5000000, 'active', '2026-01-31 19:14:48', '2026-01-31 19:14:48'),
(1941, 'ION', 'FCOI', 'Impfondo Airport', NULL, 'CG', 'Likouala', 1.6170000, 18.0670000, 'active', '2026-01-31 19:14:48', '2026-01-31 19:14:48'),
(1942, 'DIS', 'FCPL', 'Dolisie Airport', NULL, 'CG', 'Niari', -4.2063500, 12.6599000, 'active', '2026-01-31 19:14:48', '2026-01-31 19:14:48'),
(1943, 'KMK', 'FCPA', 'Makabana Airport', NULL, 'CG', 'Niari', -3.4830000, 12.6170000, 'active', '2026-01-31 19:14:49', '2026-01-31 19:14:49'),
(1944, 'MSX', 'FCMM', 'Mossendjo Airport', NULL, 'CG', 'Niari', -2.9500000, 12.7000000, 'active', '2026-01-31 19:14:49', '2026-01-31 19:14:49'),
(1945, 'DJM', 'FCBD', 'Djambala Airport', NULL, 'CG', 'Plateaux', -2.5330000, 14.7500000, 'active', '2026-01-31 19:14:49', '2026-01-31 19:14:49'),
(1946, 'GMM', 'FCOG', 'Gamboma Airport', NULL, 'CG', 'Plateaux', -1.8294000, 15.8852000, 'active', '2026-01-31 19:14:50', '2026-01-31 19:14:50'),
(1947, 'LCO', 'FCBL', 'Lague Airport', NULL, 'CG', 'Plateaux', -2.4500000, 14.5330000, 'active', '2026-01-31 19:14:50', '2026-01-31 19:14:50'),
(1948, 'LKC', NULL, 'Lekana Airport', NULL, 'CG', 'Plateaux', -2.3130000, 14.6060000, 'active', '2026-01-31 19:14:50', '2026-01-31 19:14:50'),
(1949, 'PNR', 'FCPP', 'Pointe Noire Airport', NULL, 'CG', 'Pointe-Noire', -4.8160300, 11.8866000, 'active', '2026-01-31 19:14:51', '2026-01-31 19:14:51'),
(1950, 'KNJ', 'FCBK', 'Kindamba Airport', NULL, 'CG', 'Pool', -3.9500000, 14.5170000, 'active', '2026-01-31 19:14:51', '2026-01-31 19:14:51'),
(1951, 'EPN', NULL, 'Epena Airport', NULL, 'CG', 'Sangha', 1.3666700, 17.4833000, 'active', '2026-01-31 19:14:51', '2026-01-31 19:14:51'),
(1952, 'OUE', 'FCOU', 'Ouesso Airport', NULL, 'CG', 'Sangha', 1.6159900, 16.0379000, 'active', '2026-01-31 19:14:52', '2026-01-31 19:14:52'),
(1953, 'SOE', 'FCOS', 'Souanke Airport', NULL, 'CG', 'Sangha', 2.0670000, 14.1330000, 'active', '2026-01-31 19:14:52', '2026-01-31 19:14:52'),
(1954, 'BSL', 'LFSB', 'EuroAirport Basel Mulhouse Freiburg', NULL, 'CH', 'Basel-City', 47.5900000, 7.5291600, 'active', '2026-01-31 19:14:52', '2026-01-31 19:14:52'),
(1955, 'BRN', 'LSZB', 'Bern Airport', NULL, 'CH', 'Bern', 46.9141000, 7.4971500, 'active', '2026-01-31 19:14:53', '2026-01-31 19:14:53'),
(1956, 'GVA', 'LSGG', 'Geneva Airport', NULL, 'CH', 'Geneve', 46.2381000, 6.1089500, 'active', '2026-01-31 19:14:53', '2026-01-31 19:14:53'),
(1957, 'SMV', 'LSZS', 'Samedan Airport (Engadin Airport)', NULL, 'CH', 'Graubunden', 46.5341000, 9.8841100, 'active', '2026-01-31 19:14:53', '2026-01-31 19:14:53'),
(1958, 'EML', 'LSME', 'Emmen Air Base', NULL, 'CH', 'Luzern', 47.0924000, 8.3051800, 'active', '2026-01-31 19:14:54', '2026-01-31 19:14:54'),
(1959, 'BXO', 'LSZC', 'Buochs Airport', NULL, 'CH', 'Nidwalden', 46.9744000, 8.3969400, 'active', '2026-01-31 19:14:54', '2026-01-31 19:14:54'),
(1960, 'ACH', 'LSZR', 'St. Gallen-Altenrhein Airport', NULL, 'CH', 'Sankt Gallen', 47.4850000, 9.5607700, 'active', '2026-01-31 19:14:55', '2026-01-31 19:14:55'),
(1961, 'LUG', 'LSZA', 'Lugano Airport', NULL, 'CH', 'Ticino', 46.0043000, 8.9105800, 'active', '2026-01-31 19:14:55', '2026-01-31 19:14:55'),
(1962, 'SIR', 'LSGS', 'Sion Airport', NULL, 'CH', 'Valais', 46.2196000, 7.3267600, 'active', '2026-01-31 19:14:55', '2026-01-31 19:14:55'),
(1963, 'ZRH', 'LSZH', 'Zurich Airport', NULL, 'CH', 'Zurich', 47.4647000, 8.5491700, 'active', '2026-01-31 19:14:56', '2026-01-31 19:14:56'),
(1964, 'ABJ', 'DIAP', 'Port Bouet Airport (Felix Houphouet Boigny Int\'l)', NULL, 'CI', 'Abidjan', 5.2613900, -3.9262900, 'active', '2026-01-31 19:14:56', '2026-01-31 19:14:56'),
(1965, 'OFI', 'DIOF', 'Ouango Fitini Airport', NULL, 'CI', 'Abidjan', 9.6000000, -4.0500000, 'active', '2026-01-31 19:14:56', '2026-01-31 19:14:56'),
(1966, 'BBV', 'DIGN', 'Nero-Mer Airport', NULL, 'CI', 'Bas-Sassandra', 4.6434100, -6.9239600, 'active', '2026-01-31 19:14:57', '2026-01-31 19:14:57'),
(1967, 'SPY', 'DISP', 'San Pedro Airport', NULL, 'CI', 'Bas-Sassandra', 4.7467200, -6.6608200, 'active', '2026-01-31 19:14:57', '2026-01-31 19:14:57'),
(1968, 'TXU', 'DITB', 'Tabou Airport', NULL, 'CI', 'Bas-Sassandra', 4.4378100, -7.3627300, 'active', '2026-01-31 19:14:57', '2026-01-31 19:14:57'),
(1969, 'ZSS', 'DISS', 'Sassandra Airport', NULL, 'CI', 'Bas-Sassandra', 4.9283300, -6.1327800, 'active', '2026-01-31 19:14:58', '2026-01-31 19:14:58'),
(1970, 'ABO', 'DIAO', 'Aboisso Airport', NULL, 'CI', 'Comoe', 5.4619400, -3.2347200, 'active', '2026-01-31 19:14:58', '2026-01-31 19:14:58'),
(1971, 'OGO', 'DIAU', 'Abengourou Airport', NULL, 'CI', 'Comoe', 6.7155600, -3.4702800, 'active', '2026-01-31 19:14:58', '2026-01-31 19:14:58'),
(1972, 'KEO', 'DIOD', 'Odienne Airport', NULL, 'CI', 'Denguele', 9.5000000, -7.5670000, 'active', '2026-01-31 19:14:59', '2026-01-31 19:14:59'),
(1973, 'DIV', 'DIDV', 'Divo Airport', NULL, 'CI', 'Goh-Djiboua', 6.9046100, -5.3623600, 'active', '2026-01-31 19:14:59', '2026-01-31 19:14:59'),
(1974, 'GGN', 'DIGA', 'Gagnoa Airport', NULL, 'CI', 'Goh-Djiboua', 6.1330000, -5.9500000, 'active', '2026-01-31 19:14:59', '2026-01-31 19:14:59'),
(1975, 'DIM', 'DIDK', 'Dimbokro Airport', NULL, 'CI', 'Lacs', 6.6516700, -4.6405600, 'active', '2026-01-31 19:15:00', '2026-01-31 19:15:00'),
(1976, 'GGO', 'DIGL', 'Guiglo Airport', NULL, 'CI', 'Montagnes', 6.5347100, -7.5268500, 'active', '2026-01-31 19:15:00', '2026-01-31 19:15:00'),
(1977, 'MJC', 'DIMN', 'Man Airport', NULL, 'CI', 'Montagnes', 7.2720700, -7.5873600, 'active', '2026-01-31 19:15:01', '2026-01-31 19:15:01'),
(1978, 'DJO', 'DIDL', 'Daloa Airport', NULL, 'CI', 'Sassandra-Marahoue', 6.7928100, -6.4731900, 'active', '2026-01-31 19:15:01', '2026-01-31 19:15:01'),
(1979, 'BXI', 'DIBI', 'Boundiali Airport', NULL, 'CI', 'Savanes', 9.5330000, -6.4670000, 'active', '2026-01-31 19:15:01', '2026-01-31 19:15:01'),
(1980, 'FEK', 'DIFK', 'Ferkessedougou Airport', NULL, 'CI', 'Savanes', 9.6000000, -5.1833300, 'active', '2026-01-31 19:15:02', '2026-01-31 19:15:02'),
(1981, 'HGO', 'DIKO', 'Korhogo Airport', NULL, 'CI', 'Savanes', 9.3871800, -5.5566600, 'active', '2026-01-31 19:15:02', '2026-01-31 19:15:02'),
(1982, 'BYK', 'DIBK', 'Bouake Airport', NULL, 'CI', 'Vallee du Bandama', 7.7388000, -5.0736700, 'active', '2026-01-31 19:15:02', '2026-01-31 19:15:02'),
(1983, 'KTC', NULL, 'Katiola Airport', NULL, 'CI', 'Vallee du Bandama', 8.1329000, -5.0657000, 'active', '2026-01-31 19:15:03', '2026-01-31 19:15:03'),
(1984, 'SEO', 'DISG', 'Seguela Airport', NULL, 'CI', 'Woroba', 7.9683300, -6.7108300, 'active', '2026-01-31 19:15:03', '2026-01-31 19:15:03'),
(1985, 'TOZ', 'DITM', 'Mahana Airport', NULL, 'CI', 'Woroba', 8.2934000, -7.6740000, 'active', '2026-01-31 19:15:03', '2026-01-31 19:15:03'),
(1986, 'ASK', 'DIYO', 'Yamoussoukro International Airport', NULL, 'CI', 'Yamoussoukro', 6.9031700, -5.3655800, 'active', '2026-01-31 19:15:04', '2026-01-31 19:15:04'),
(1987, 'BDK', 'DIBU', 'Soko Airport', NULL, 'CI', 'Zanzan', 8.0172200, -2.7619400, 'active', '2026-01-31 19:15:04', '2026-01-31 19:15:04'),
(1988, 'BQO', 'DIBN', 'Tehini Airport', NULL, 'CI', 'Zanzan', 9.2775000, -3.0252800, 'active', '2026-01-31 19:15:04', '2026-01-31 19:15:04'),
(1989, 'AIT', 'NCAI', 'Aitutaki Airport', NULL, 'CK', 'Cook Islands', -18.8309000, -159.7640000, 'active', '2026-01-31 19:15:05', '2026-01-31 19:15:05'),
(1990, 'AIU', 'NCAT', 'Enua Airport', NULL, 'CK', 'Cook Islands', -19.9678000, -158.1190000, 'active', '2026-01-31 19:15:05', '2026-01-31 19:15:05'),
(1991, 'MGS', 'NCMG', 'Mangaia Airport', NULL, 'CK', 'Cook Islands', -21.8960000, -157.9070000, 'active', '2026-01-31 19:15:05', '2026-01-31 19:15:05'),
(1992, 'MHX', 'NCMH', 'Manihiki Island Airport', NULL, 'CK', 'Cook Islands', -10.3767000, -161.0020000, 'active', '2026-01-31 19:15:06', '2026-01-31 19:15:06'),
(1993, 'MOI', 'NCMR', 'Mitiaro Airport (Nukuroa Airport)', NULL, 'CK', 'Cook Islands', -19.8425000, -157.7030000, 'active', '2026-01-31 19:15:06', '2026-01-31 19:15:06'),
(1994, 'MUK', 'NCMK', 'Mauke Airport', NULL, 'CK', 'Cook Islands', -20.1361000, -157.3450000, 'active', '2026-01-31 19:15:06', '2026-01-31 19:15:06'),
(1995, 'PYE', 'NCPY', 'Tongareva Airport', NULL, 'CK', 'Cook Islands', -9.0143700, -158.0320000, 'active', '2026-01-31 19:15:07', '2026-01-31 19:15:07'),
(1996, 'PZK', 'NCPK', 'Pukapuka Island Airfield', NULL, 'CK', 'Cook Islands', -10.9145000, -165.8390000, 'active', '2026-01-31 19:15:07', '2026-01-31 19:15:07'),
(1997, 'RAR', 'NCRG', 'Rarotonga International Airport', NULL, 'CK', 'Cook Islands', -21.2027000, -159.8060000, 'active', '2026-01-31 19:15:07', '2026-01-31 19:15:07'),
(1998, 'BBA', 'SCBA', 'Balmaceda Airport', NULL, 'CL', 'Aisen del General Carlos Ibanez del Campo', -45.9161000, -71.6895000, 'active', '2026-01-31 19:15:08', '2026-01-31 19:15:08'),
(1999, 'CCH', 'SCCC', 'Chile Chico Airfield', NULL, 'CL', 'Aisen del General Carlos Ibanez del Campo', -46.5833000, -71.6874000, 'active', '2026-01-31 19:15:08', '2026-01-31 19:15:08'),
(2000, 'GXQ', 'SCCY', 'Teniente Vidal Airfield', NULL, 'CL', 'Aisen del General Carlos Ibanez del Campo', -45.5942000, -72.1061000, 'active', '2026-01-31 19:15:08', '2026-01-31 19:15:08'),
(2001, 'LGR', 'SCHR', 'Cochrane Airfield', NULL, 'CL', 'Aisen del General Carlos Ibanez del Campo', -47.2438000, -72.5884000, 'active', '2026-01-31 19:15:09', '2026-01-31 19:15:09'),
(2002, 'WPA', 'SCAS', 'Cabo Juan Roman Airfield', NULL, 'CL', 'Aisen del General Carlos Ibanez del Campo', -45.3992000, -72.6703000, 'active', '2026-01-31 19:15:09', '2026-01-31 19:15:09'),
(2003, 'ANF', 'SCFA', 'Cerro Moreno International Airport', NULL, 'CL', 'Antofagasta', -23.4445000, -70.4451000, 'active', '2026-01-31 19:15:10', '2026-01-31 19:15:10'),
(2004, 'CJC', 'SCCF', 'El Loa Airport', NULL, 'CL', 'Antofagasta', -22.4982000, -68.9036000, 'active', '2026-01-31 19:15:10', '2026-01-31 19:15:10'),
(2005, 'TOQ', 'SCBE', 'Barriles Airport', NULL, 'CL', 'Antofagasta', -22.1411000, -70.0629000, 'active', '2026-01-31 19:15:10', '2026-01-31 19:15:10'),
(2006, 'TTC', 'SCTT', 'Las Breas Airport', NULL, 'CL', 'Antofagasta', -25.5643000, -70.3759000, 'active', '2026-01-31 19:15:11', '2026-01-31 19:15:11'),
(2007, 'ARI', 'SCAR', 'Chacalluta International Airport', NULL, 'CL', 'Arica y Parinacota', -18.3485000, -70.3387000, 'active', '2026-01-31 19:15:11', '2026-01-31 19:15:11'),
(2008, 'CNR', 'SCRA', 'Chanaral Airport', NULL, 'CL', 'Atacama', -26.3325000, -70.6073000, 'active', '2026-01-31 19:15:11', '2026-01-31 19:15:11'),
(2009, 'CPO', 'SCAT', 'Desierto de Atacama Airport', NULL, 'CL', 'Atacama', -27.2612000, -70.7792000, 'active', '2026-01-31 19:15:12', '2026-01-31 19:15:12'),
(2010, 'ESR', 'SCES', 'Ricardo Garcia Posada Airport', NULL, 'CL', 'Atacama', -26.3111000, -69.7652000, 'active', '2026-01-31 19:15:12', '2026-01-31 19:15:12'),
(2011, 'VLR', 'SCLL', 'Vallenar Airport', NULL, 'CL', 'Atacama', -28.5964000, -70.7560000, 'active', '2026-01-31 19:15:12', '2026-01-31 19:15:12'),
(2012, 'CCP', 'SCIE', 'Carriel Sur International Airport', NULL, 'CL', 'Biobio', -36.7727000, -73.0631000, 'active', '2026-01-31 19:15:13', '2026-01-31 19:15:13'),
(2013, 'LSQ', 'SCGE', 'Maria Dolores Airport', NULL, 'CL', 'Biobio', -37.4017000, -72.4254000, 'active', '2026-01-31 19:15:13', '2026-01-31 19:15:13'),
(2014, 'YAI', 'SCCH', 'General Bernardo O\'Higgins Airport', NULL, 'CL', 'Biobio', -36.5825000, -72.0314000, 'active', '2026-01-31 19:15:13', '2026-01-31 19:15:13'),
(2015, 'COW', 'SCQB', 'Coquimbo Airport', NULL, 'CL', 'Coquimbo', -30.1989000, -71.2469000, 'active', '2026-01-31 19:15:14', '2026-01-31 19:15:14'),
(2016, 'LSC', 'SCSE', 'La Florida Airport', NULL, 'CL', 'Coquimbo', -29.9162000, -71.1995000, 'active', '2026-01-31 19:15:14', '2026-01-31 19:15:14'),
(2017, 'OVL', 'SCOV', 'El Tuqui Airport', NULL, 'CL', 'Coquimbo', -30.5592000, -71.1756000, 'active', '2026-01-31 19:15:14', '2026-01-31 19:15:14'),
(2018, 'PZS', 'SCTC', 'Maquehue Airport', NULL, 'CL', 'La Araucania', -38.7668000, -72.6371000, 'active', '2026-01-31 19:15:15', '2026-01-31 19:15:15'),
(2019, 'ZCO', 'SCQP', 'La Araucania Airport', NULL, 'CL', 'La Araucania', -38.9259000, -72.6515000, 'active', '2026-01-31 19:15:15', '2026-01-31 19:15:15'),
(2020, 'ZIC', 'SCTO', 'Victoria Airport', NULL, 'CL', 'La Araucania', -38.2456000, -72.3486000, 'active', '2026-01-31 19:15:15', '2026-01-31 19:15:15'),
(2021, 'ZPC', 'SCPC', 'Pucon Airport', NULL, 'CL', 'La Araucania', -39.2928000, -71.9159000, 'active', '2026-01-31 19:15:16', '2026-01-31 19:15:16'),
(2022, 'FFU', 'SCFT', 'Futaleufu Airfield', NULL, 'CL', 'Los Lagos', -43.1892000, -71.8511000, 'active', '2026-01-31 19:15:16', '2026-01-31 19:15:16'),
(2023, 'FRT', 'SCFR', 'Frutillar Airport', NULL, 'CL', 'Los Lagos', -41.1170000, -73.0500000, 'active', '2026-01-31 19:15:16', '2026-01-31 19:15:16'),
(2024, 'MHC', 'SCPQ', 'Mocopulli Airport', NULL, 'CL', 'Los Lagos', -42.3404000, -73.7157000, 'active', '2026-01-31 19:15:17', '2026-01-31 19:15:17'),
(2025, 'PMC', 'SCTE', 'El Tepual Airport', NULL, 'CL', 'Los Lagos', -41.4389000, -73.0940000, 'active', '2026-01-31 19:15:17', '2026-01-31 19:15:17'),
(2026, 'PUX', 'SCPV', 'El Mirador Airport', NULL, 'CL', 'Los Lagos', -41.3494000, -72.9467000, 'active', '2026-01-31 19:15:17', '2026-01-31 19:15:17'),
(2027, 'WAP', 'SCAP', 'Alto Palena Airfield', NULL, 'CL', 'Los Lagos', -43.6119000, -71.8061000, 'active', '2026-01-31 19:15:18', '2026-01-31 19:15:18'),
(2028, 'WCA', 'SCST', 'Gamboa Airport', NULL, 'CL', 'Los Lagos', -42.4903000, -73.7728000, 'active', '2026-01-31 19:15:18', '2026-01-31 19:15:18'),
(2029, 'WCH', 'SCTN', 'Chaiten Airfield', NULL, 'CL', 'Los Lagos', -42.9328000, -72.6991000, 'active', '2026-01-31 19:15:18', '2026-01-31 19:15:18'),
(2030, 'ZOS', 'SCJO', 'Canal Bajo Carlos Hott Siebert Airport', NULL, 'CL', 'Los Lagos', -40.6112000, -73.0610000, 'active', '2026-01-31 19:15:19', '2026-01-31 19:15:19'),
(2031, 'ZUD', 'SCAC', 'Pupelde Airfield', NULL, 'CL', 'Los Lagos', -41.9043000, -73.7966000, 'active', '2026-01-31 19:15:19', '2026-01-31 19:15:19'),
(2032, 'ZAL', 'SCVD', 'Pichoy Airport', NULL, 'CL', 'Los Rios', -39.6500000, -73.0861000, 'active', '2026-01-31 19:15:19', '2026-01-31 19:15:19'),
(2033, 'PNT', 'SCNT', 'Teniente Julio Gallardo Airport', NULL, 'CL', 'Magallanes', -51.6715000, -72.5284000, 'active', '2026-01-31 19:15:20', '2026-01-31 19:15:20'),
(2034, 'PUQ', 'SCCI', 'Presidente Carlos Ibanez del Campo International Airport', NULL, 'CL', 'Magallanes', -53.0026000, -70.8546000, 'active', '2026-01-31 19:15:20', '2026-01-31 19:15:20'),
(2035, 'SMB', 'SCSB', 'Franco Bianco Airport', NULL, 'CL', 'Magallanes', -52.7367000, -69.3336000, 'active', '2026-01-31 19:15:20', '2026-01-31 19:15:20'),
(2036, 'WPR', 'SCFM', 'Capitan Fuentes Martinez Airport', NULL, 'CL', 'Magallanes', -53.2537000, -70.3192000, 'active', '2026-01-31 19:15:21', '2026-01-31 19:15:21'),
(2037, 'WPU', 'SCGZ', 'Guardiamarina Zanartu Airport', NULL, 'CL', 'Magallanes', -54.9311000, -67.6263000, 'active', '2026-01-31 19:15:21', '2026-01-31 19:15:21'),
(2038, 'TLX', 'SCTL', 'Panguilemo Airport', NULL, 'CL', 'Maule', -35.3778000, -71.6017000, 'active', '2026-01-31 19:15:21', '2026-01-31 19:15:21'),
(2039, 'SCL', 'SCEL', 'Arturo Merino Benítez International Airport', NULL, 'CL', 'Region Metropolitana de Santiago', -33.3928000, -70.7856000, 'active', '2026-01-31 19:15:22', '2026-01-31 19:15:22'),
(2040, 'CPP', 'SCKP', 'Coposa Airport', NULL, 'CL', 'Tarapaca', -20.7500000, -68.6833000, 'active', '2026-01-31 19:15:22', '2026-01-31 19:15:22'),
(2041, 'IQQ', 'SCDA', 'Diego Aracena International Airport', NULL, 'CL', 'Tarapaca', -20.5352000, -70.1813000, 'active', '2026-01-31 19:15:23', '2026-01-31 19:15:23'),
(2042, 'IPC', 'SCIP', 'Mataveri International Airport (Isla de Pascua Airport)', NULL, 'CL', 'Valparaiso', -27.1648000, -109.4220000, 'active', '2026-01-31 19:15:23', '2026-01-31 19:15:23'),
(2043, 'KNA', 'SCVM', 'Vina del Mar Airport', NULL, 'CL', 'Valparaiso', -32.9496000, -71.4786000, 'active', '2026-01-31 19:15:23', '2026-01-31 19:15:23'),
(2044, 'LOB', 'SCAN', 'San Rafael Airport', NULL, 'CL', 'Valparaiso', -32.8142000, -70.6467000, 'active', '2026-01-31 19:15:24', '2026-01-31 19:15:24'),
(2045, 'VAP', 'SCRD', 'Rodelillo Airfield', NULL, 'CL', 'Valparaiso', -33.0681000, -71.5575000, 'active', '2026-01-31 19:15:24', '2026-01-31 19:15:24'),
(2046, 'NGE', 'FKKN', 'Ngaoundere Airport', NULL, 'CM', 'Adamaoua', 7.3570100, 13.5592000, 'active', '2026-01-31 19:15:24', '2026-01-31 19:15:24'),
(2047, 'NSI', 'FKYS', 'Yaounde Nsimalen International Airport', NULL, 'CM', 'Centre', 3.7225600, 11.5533000, 'active', '2026-01-31 19:15:25', '2026-01-31 19:15:25'),
(2048, 'YAO', 'FKKY', 'Yaounde Airport', NULL, 'CM', 'Centre', 3.8360400, 11.5235000, 'active', '2026-01-31 19:15:25', '2026-01-31 19:15:25'),
(2049, 'BTA', 'FKKO', 'Bertoua Airport', NULL, 'CM', 'Est', 4.5486100, 13.7261000, 'active', '2026-01-31 19:15:25', '2026-01-31 19:15:25'),
(2050, 'OUR', 'FKKI', 'Batouri Airport', NULL, 'CM', 'Est', 4.4750000, 14.3625000, 'active', '2026-01-31 19:15:26', '2026-01-31 19:15:26'),
(2051, 'GXX', 'FKKJ', 'Yagoua Airport', NULL, 'CM', 'Extreme-Nord', 10.3561000, 15.2372000, 'active', '2026-01-31 19:15:26', '2026-01-31 19:15:26'),
(2052, 'KLE', 'FKKH', 'Kaele Airport', NULL, 'CM', 'Extreme-Nord', 10.0925000, 14.4456000, 'active', '2026-01-31 19:15:26', '2026-01-31 19:15:26'),
(2053, 'MVR', 'FKKL', 'Salak Airport', NULL, 'CM', 'Extreme-Nord', 10.4514000, 14.2574000, 'active', '2026-01-31 19:15:27', '2026-01-31 19:15:27'),
(2054, 'DLA', 'FKKD', 'Douala International Airport', NULL, 'CM', 'Littoral', 4.0060800, 9.7194800, 'active', '2026-01-31 19:15:27', '2026-01-31 19:15:27'),
(2055, 'NKS', 'FKAN', 'Nkongsamba Airport', NULL, 'CM', 'Littoral', 4.9500000, 9.9330000, 'active', '2026-01-31 19:15:27', '2026-01-31 19:15:27'),
(2056, 'GOU', 'FKKR', 'Garoua International Airport', NULL, 'CM', 'Nord', 9.3358900, 13.3701000, 'active', '2026-01-31 19:15:28', '2026-01-31 19:15:28'),
(2057, 'BLC', 'FKKG', 'Bali Airport', NULL, 'CM', 'Nord-Ouest', 5.8952800, 10.0339000, 'active', '2026-01-31 19:15:28', '2026-01-31 19:15:28'),
(2058, 'BPC', 'FKKV', 'Bamenda Airport', NULL, 'CM', 'Nord-Ouest', 6.0392400, 10.1226000, 'active', '2026-01-31 19:15:28', '2026-01-31 19:15:28'),
(2059, 'BFX', 'FKKU', 'Bafoussam Airport', NULL, 'CM', 'Ouest', 5.5369200, 10.3546000, 'active', '2026-01-31 19:15:29', '2026-01-31 19:15:29'),
(2060, 'DSC', 'FKKS', 'Dschang Airport', NULL, 'CM', 'Ouest', 5.4500000, 10.0670000, 'active', '2026-01-31 19:15:29', '2026-01-31 19:15:29'),
(2061, 'FOM', 'FKKM', 'Foumban Nkounja Airport', NULL, 'CM', 'Ouest', 5.6369200, 10.7508000, 'active', '2026-01-31 19:15:29', '2026-01-31 19:15:29'),
(2062, 'EBW', 'FKKW', 'Ebolowa Airport', NULL, 'CM', 'Sud', 2.8760000, 11.1850000, 'active', '2026-01-31 19:15:30', '2026-01-31 19:15:30'),
(2063, 'KBI', 'FKKB', 'Kribi Airport', NULL, 'CM', 'Sud', 2.8738900, 9.9777800, 'active', '2026-01-31 19:15:30', '2026-01-31 19:15:30'),
(2064, 'MMF', 'FKKF', 'Mamfe Airport', NULL, 'CM', 'Sud-Ouest', 5.7041700, 9.3063900, 'active', '2026-01-31 19:15:30', '2026-01-31 19:15:30'),
(2065, 'TKC', 'FKKC', 'Tiko Airport', NULL, 'CM', 'Sud-Ouest', 4.0891900, 9.3605300, 'active', '2026-01-31 19:15:31', '2026-01-31 19:15:31'),
(2066, 'AQG', 'ZSAQ', 'Anqing Tianzhushan Airport', NULL, 'CN', 'Anhui', 30.5822000, 117.0500000, 'active', '2026-01-31 19:15:31', '2026-01-31 19:15:31'),
(2067, 'BFU', 'ZSBB', 'Bengbu Airport', NULL, 'CN', 'Anhui', 32.8477000, 117.3200000, 'active', '2026-01-31 19:15:31', '2026-01-31 19:15:31'),
(2068, 'FUG', 'ZSFY', 'Fuyang Xiguan Airport', NULL, 'CN', 'Anhui', 32.8822000, 115.7340000, 'active', '2026-01-31 19:15:32', '2026-01-31 19:15:32'),
(2069, 'HFE', 'ZSOF', 'Hefei Xinqiao International Airport', NULL, 'CN', 'Anhui', 31.7800000, 117.2980000, 'active', '2026-01-31 19:15:32', '2026-01-31 19:15:32'),
(2070, 'JUH', NULL, 'Chizhou Jiuhuashan Airport', NULL, 'CN', 'Anhui', 30.7403000, 117.6860000, 'active', '2026-01-31 19:15:33', '2026-01-31 19:15:33'),
(2071, 'TXN', 'ZSTX', 'Huangshan Tunxi International Airport', NULL, 'CN', 'Anhui', 29.7333000, 118.2560000, 'active', '2026-01-31 19:15:33', '2026-01-31 19:15:33'),
(2072, 'WHA', 'ZSWA', 'Wuhu Airport', NULL, 'CN', 'Anhui', 31.3906000, 118.4090000, 'active', '2026-01-31 19:15:33', '2026-01-31 19:15:33'),
(2073, 'PEK', 'ZBAA', 'Beijing Capital International Airport', NULL, 'CN', 'Beijing', 40.0725000, 116.5980000, 'active', '2026-01-31 19:15:34', '2026-01-31 19:15:34'),
(2074, 'PKX', 'ZBAD', 'Daxing International Airport', NULL, 'CN', 'Beijing', 39.5101000, 116.4101000, 'active', '2026-01-31 19:15:34', '2026-01-31 19:15:34'),
(2075, 'CQW', 'ZUWL', 'Chongqing Xiannyushan Airport', NULL, 'CN', 'Chongqing Shi', 29.4658000, 107.6920000, 'active', '2026-01-31 19:15:34', '2026-01-31 19:15:34'),
(2076, 'WSK', 'ZUWS', 'Chongqing Wushan Airport', NULL, 'CN', 'Chongqing Shi', 31.0640000, 109.7060000, 'active', '2026-01-31 19:15:35', '2026-01-31 19:15:35'),
(2077, 'CKG', 'ZUCK', 'Chongqing Jiangbei International Airport', NULL, 'CN', 'Chongqing', 29.7192000, 106.6420000, 'active', '2026-01-31 19:15:35', '2026-01-31 19:15:35'),
(2078, 'DZU', 'ZUDZ', 'Dazu Air Base', NULL, 'CN', 'Chongqing', 29.6362000, 105.7740000, 'active', '2026-01-31 19:15:35', '2026-01-31 19:15:35'),
(2079, 'JIQ', 'ZUQJ', 'Qianjiang Wulingshan Airport', NULL, 'CN', 'Chongqing', 29.5133000, 108.8310000, 'active', '2026-01-31 19:15:36', '2026-01-31 19:15:36'),
(2080, 'LIA', 'ZULP', 'Liangping Airport', NULL, 'CN', 'Chongqing', 30.6794000, 107.7860000, 'active', '2026-01-31 19:15:36', '2026-01-31 19:15:36'),
(2081, 'WXN', 'ZUWX', 'Wanzhou Wuqiao Airport', NULL, 'CN', 'Chongqing', 30.8017000, 108.4330000, 'active', '2026-01-31 19:15:36', '2026-01-31 19:15:36'),
(2082, 'FOC', 'ZSFZ', 'Fuzhou Changle International Airport', NULL, 'CN', 'Fujian', 25.9351000, 119.6630000, 'active', '2026-01-31 19:15:37', '2026-01-31 19:15:37'),
(2083, 'JJN', 'ZSQZ', 'Quanzhou Jinjiang International Airport', NULL, 'CN', 'Fujian', 24.7964000, 118.5900000, 'active', '2026-01-31 19:15:37', '2026-01-31 19:15:37'),
(2084, 'LCX', 'ZSLO', 'Longyan Guanzhishan Airport', NULL, 'CN', 'Fujian', 25.6747000, 116.7470000, 'active', '2026-01-31 19:15:37', '2026-01-31 19:15:37'),
(2085, 'SQJ', 'ZSSM', 'Sanming Shaxian Airport', NULL, 'CN', 'Fujian', 26.4263000, 117.8340000, 'active', '2026-01-31 19:15:38', '2026-01-31 19:15:38'),
(2086, 'WUS', 'ZSWY', 'Wuyishan Airport', NULL, 'CN', 'Fujian', 27.7019000, 118.0010000, 'active', '2026-01-31 19:15:38', '2026-01-31 19:15:38'),
(2087, 'XMN', 'ZSAM', 'Xiamen Gaoqi International Airport', NULL, 'CN', 'Fujian', 24.5440000, 118.1280000, 'active', '2026-01-31 19:15:38', '2026-01-31 19:15:38'),
(2088, 'DNH', 'ZLDH', 'Dunhuang Airport', NULL, 'CN', 'Gansu', 40.1611000, 94.8092000, 'active', '2026-01-31 19:15:39', '2026-01-31 19:15:39'),
(2089, 'GXH', 'ZLXH', 'Gannan Xiahe Airport', NULL, 'CN', 'Gansu', 34.8105000, 102.6450000, 'active', '2026-01-31 19:15:39', '2026-01-31 19:15:39'),
(2090, 'IQN', 'ZLQY', 'Qingyang Airport', NULL, 'CN', 'Gansu', 35.7997000, 107.6030000, 'active', '2026-01-31 19:15:39', '2026-01-31 19:15:39'),
(2091, 'JGN', 'ZLJQ', 'Jiayuguan Airport', NULL, 'CN', 'Gansu', 39.8569000, 98.3414000, 'active', '2026-01-31 19:15:40', '2026-01-31 19:15:40'),
(2092, 'JIC', 'ZLJC', 'Jinchang Jinchuan Airport', NULL, 'CN', 'Gansu', 38.5422000, 102.3480000, 'active', '2026-01-31 19:15:40', '2026-01-31 19:15:40'),
(2093, 'LHW', 'ZLLL', 'Lanzhou Zhongchuan International Airport', NULL, 'CN', 'Gansu', 36.5152000, 103.6200000, 'active', '2026-01-31 19:15:40', '2026-01-31 19:15:40'),
(2094, 'LNL', 'ZLLN', 'Longnan Chengzhou Airport', NULL, 'CN', 'Gansu', 33.7880000, 105.7970000, 'active', '2026-01-31 19:15:41', '2026-01-31 19:15:41'),
(2095, 'THQ', 'ZLTS', 'Tianshui Maijishan Airport', NULL, 'CN', 'Gansu', 34.5594000, 105.8600000, 'active', '2026-01-31 19:15:41', '2026-01-31 19:15:41'),
(2096, 'YZY', 'ZLZY', 'Zhangye Ganzhou Airport', NULL, 'CN', 'Gansu', 38.8019000, 100.6750000, 'active', '2026-01-31 19:15:41', '2026-01-31 19:15:41'),
(2097, 'CAN', 'ZGGG', 'Guangzhou Baiyun International Airport', NULL, 'CN', 'Guangdong', 23.3924000, 113.2990000, 'active', '2026-01-31 19:15:42', '2026-01-31 19:15:42'),
(2098, 'FUO', 'ZGFS', 'Foshan Shadi Airport', NULL, 'CN', 'Guangdong', 23.0833000, 113.0700000, 'active', '2026-01-31 19:15:42', '2026-01-31 19:15:42'),
(2099, 'HSC', NULL, 'Shaoguan Guitou Airport', NULL, 'CN', 'Guangdong', 24.9786000, 113.4210000, 'active', '2026-01-31 19:15:42', '2026-01-31 19:15:42'),
(2100, 'HUZ', 'ZGHZ', 'Huizhou Pingtan Airport', NULL, 'CN', 'Guangdong', 23.0500000, 114.6000000, 'active', '2026-01-31 19:15:43', '2026-01-31 19:15:43'),
(2101, 'MXZ', 'ZGMX', 'Meixian Airport', NULL, 'CN', 'Guangdong', 24.3500000, 116.1330000, 'active', '2026-01-31 19:15:44', '2026-01-31 19:15:44'),
(2102, 'SWA', 'ZGOW', 'Jieyang Chaoshan International Airport', NULL, 'CN', 'Guangdong', 23.5520000, 116.5030000, 'active', '2026-01-31 19:15:44', '2026-01-31 19:15:44'),
(2103, 'SZX', 'ZGSZ', 'Shenzhen Bao\'an International Airport', NULL, 'CN', 'Guangdong', 22.6393000, 113.8110000, 'active', '2026-01-31 19:15:44', '2026-01-31 19:15:44'),
(2104, 'XIN', 'ZGXN', 'Xingning Air Base', NULL, 'CN', 'Guangdong', 24.1492000, 115.7580000, 'active', '2026-01-31 19:15:45', '2026-01-31 19:15:45'),
(2105, 'ZHA', 'ZGZJ', 'Zhanjiang Airport', NULL, 'CN', 'Guangdong', 21.2144000, 110.3580000, 'active', '2026-01-31 19:15:45', '2026-01-31 19:15:45'),
(2106, 'ZUH', 'ZGSD', 'Zhuhai Jinwan Airport (Zhuhai Sanzao Airport)', NULL, 'CN', 'Guangdong', 22.0064000, 113.3760000, 'active', '2026-01-31 19:15:45', '2026-01-31 19:15:45'),
(2107, 'AEB', 'ZGBS', 'Baise Bama Airport', NULL, 'CN', 'Guangxi', 23.7206000, 106.9600000, 'active', '2026-01-31 19:15:46', '2026-01-31 19:15:46'),
(2108, 'BHY', 'ZGBH', 'Beihai Fucheng Airport', NULL, 'CN', 'Guangxi', 21.5394000, 109.2940000, 'active', '2026-01-31 19:15:46', '2026-01-31 19:15:46'),
(2109, 'HCJ', 'ZGHC', 'Hechi Jinchengjiang Airport', NULL, 'CN', 'Guangxi', 24.8050000, 107.7000000, 'active', '2026-01-31 19:15:46', '2026-01-31 19:15:46'),
(2110, 'KWL', 'ZGKL', 'Guilin Liangjiang International Airport', NULL, 'CN', 'Guangxi', 25.2181000, 110.0390000, 'active', '2026-01-31 19:15:47', '2026-01-31 19:15:47'),
(2111, 'LZH', 'ZGZH', 'Liuzhou Bailian Airport', NULL, 'CN', 'Guangxi', 24.2075000, 109.3910000, 'active', '2026-01-31 19:15:47', '2026-01-31 19:15:47'),
(2112, 'NNG', 'ZGNN', 'Nanning Wuxu International Airport', NULL, 'CN', 'Guangxi', 22.6083000, 108.1720000, 'active', '2026-01-31 19:15:47', '2026-01-31 19:15:47'),
(2113, 'WUZ', 'ZGWZ', 'Wuzhou Xijiang Airport', NULL, 'CN', 'Guangxi', 23.4567000, 111.2480000, 'active', '2026-01-31 19:15:48', '2026-01-31 19:15:48'),
(2114, 'YLX', NULL, 'Yulin Fumian Airport', NULL, 'CN', 'Guangxi', 22.4382000, 110.1187000, 'active', '2026-01-31 19:15:48', '2026-01-31 19:15:48'),
(2115, 'ACX', 'ZUYI', 'Xingyi Wanfenglin Airport', NULL, 'CN', 'Guizhou', 25.0864000, 104.9590000, 'active', '2026-01-31 19:15:48', '2026-01-31 19:15:48'),
(2116, 'AVA', 'ZUAS', 'Anshun Huangguoshu Airport', NULL, 'CN', 'Guizhou', 26.2606000, 105.8730000, 'active', '2026-01-31 19:15:49', '2026-01-31 19:15:49'),
(2117, 'BFJ', 'ZUBJ', 'Bijie Feixiong Airport', NULL, 'CN', 'Guizhou', 27.2671000, 105.4720000, 'active', '2026-01-31 19:15:49', '2026-01-31 19:15:49'),
(2118, 'HZH', 'ZUNP', 'Liping Airport', NULL, 'CN', 'Guizhou', 26.3222000, 109.1500000, 'active', '2026-01-31 19:15:49', '2026-01-31 19:15:49'),
(2119, 'KJH', NULL, 'Kaili Huangping Airport', NULL, 'CN', 'Guizhou', 26.9720000, 107.9880000, 'active', '2026-01-31 19:15:50', '2026-01-31 19:15:50'),
(2120, 'KWE', 'ZUGY', 'Guiyang Longdongbao International Airport', NULL, 'CN', 'Guizhou', 26.5385000, 106.8010000, 'active', '2026-01-31 19:15:50', '2026-01-31 19:15:50'),
(2121, 'LLB', 'ZULB', 'Libo Airport (Qiannan Airport)', NULL, 'CN', 'Guizhou', 25.4525000, 107.9620000, 'active', '2026-01-31 19:15:50', '2026-01-31 19:15:50'),
(2122, 'LPF', 'ZUPS', 'Liupanshui Yuezhao Airport', NULL, 'CN', 'Guizhou', 26.6094000, 104.9790000, 'active', '2026-01-31 19:15:51', '2026-01-31 19:15:51'),
(2123, 'TEN', 'ZUTR', 'Tongren Fenghuang Airport', NULL, 'CN', 'Guizhou', 27.8833000, 109.3090000, 'active', '2026-01-31 19:15:51', '2026-01-31 19:15:51'),
(2124, 'WMT', 'ZUMT', 'Zunyi Maotai Airport', NULL, 'CN', 'Guizhou', 27.8164000, 106.3330000, 'active', '2026-01-31 19:15:51', '2026-01-31 19:15:51'),
(2125, 'ZYI', 'ZUZY', 'Zunyi Xinzhou Airport', NULL, 'CN', 'Guizhou', 27.5895000, 107.0010000, 'active', '2026-01-31 19:15:52', '2026-01-31 19:15:52'),
(2126, 'BAR', NULL, 'Qionghai Bo\'ao Airport', NULL, 'CN', 'Hainan', 19.1382000, 110.4550000, 'active', '2026-01-31 19:15:52', '2026-01-31 19:15:52'),
(2127, 'HAK', 'ZJHK', 'Haikou Meilan International Airport', NULL, 'CN', 'Hainan', 19.9349000, 110.4590000, 'active', '2026-01-31 19:15:52', '2026-01-31 19:15:52'),
(2128, 'SYX', 'ZJSY', 'Sanya Phoenix International Airport', NULL, 'CN', 'Hainan', 18.3029000, 109.4120000, 'active', '2026-01-31 19:15:53', '2026-01-31 19:15:53'),
(2129, 'BPE', 'ZBDH', 'Qinhuangdao Beidaihe Airport', NULL, 'CN', 'Hebei', 39.6664000, 119.0590000, 'active', '2026-01-31 19:15:53', '2026-01-31 19:15:53'),
(2130, 'CDE', 'ZBCD', 'Chengde Puning Airport', NULL, 'CN', 'Hebei', 41.1225000, 118.0740000, 'active', '2026-01-31 19:15:53', '2026-01-31 19:15:53'),
(2131, 'HDG', 'ZBHD', 'Handan Airport', NULL, 'CN', 'Hebei', 36.5258000, 114.4260000, 'active', '2026-01-31 19:15:54', '2026-01-31 19:15:54'),
(2132, 'SJW', 'ZBSJ', 'Shijiazhuang Zhengding International Airport', NULL, 'CN', 'Hebei', 38.2807000, 114.6970000, 'active', '2026-01-31 19:15:54', '2026-01-31 19:15:54'),
(2133, 'TVS', 'ZBTS', 'Tangshan Sannuhe Airport', NULL, 'CN', 'Hebei', 39.7178000, 118.0030000, 'active', '2026-01-31 19:15:54', '2026-01-31 19:15:54'),
(2134, 'XNT', 'ZBXT', 'Xingtai Dalian Airport', NULL, 'CN', 'Hebei', 36.8831000, 114.4290000, 'active', '2026-01-31 19:15:55', '2026-01-31 19:15:55'),
(2135, 'ZQZ', 'ZBZJ', 'Zhangjiakou Ningyuan Airport', NULL, 'CN', 'Hebei', 40.7386000, 114.9300000, 'active', '2026-01-31 19:15:55', '2026-01-31 19:15:55'),
(2136, 'DQA', 'ZYDQ', 'Daqing Sartu Airport', NULL, 'CN', 'Heilongjiang', 46.7464000, 125.1410000, 'active', '2026-01-31 19:15:55', '2026-01-31 19:15:55'),
(2137, 'DTU', NULL, 'Wudalianchi Airport', NULL, 'CN', 'Heilongjiang', 48.4450000, 126.1330000, 'active', '2026-01-31 19:15:56', '2026-01-31 19:15:56'),
(2138, 'FYJ', 'ZYFY', 'Fuyuan Dongji Airport', NULL, 'CN', 'Heilongjiang', 48.1995000, 134.3660000, 'active', '2026-01-31 19:15:56', '2026-01-31 19:15:56'),
(2139, 'HEK', 'ZYHE', 'Heihe Airport', NULL, 'CN', 'Heilongjiang', 50.1716000, 127.3090000, 'active', '2026-01-31 19:15:56', '2026-01-31 19:15:56'),
(2140, 'HRB', 'ZYHB', 'Harbin Taiping International Airport', NULL, 'CN', 'Heilongjiang', 45.6234000, 126.2500000, 'active', '2026-01-31 19:15:57', '2026-01-31 19:15:57'),
(2141, 'JGD', 'ZYJD', 'Jiagedaqi Airport', NULL, 'CN', 'Heilongjiang', 50.3714000, 124.1180000, 'active', '2026-01-31 19:15:57', '2026-01-31 19:15:57'),
(2142, 'JMU', 'ZYJM', 'Jiamusi Dongjiao Airport', NULL, 'CN', 'Heilongjiang', 46.8434000, 130.4650000, 'active', '2026-01-31 19:15:57', '2026-01-31 19:15:57'),
(2143, 'JSJ', 'ZYJS', 'Jiansanjiang Airport', NULL, 'CN', 'Heilongjiang', 47.1100000, 132.6600000, 'active', '2026-01-31 19:15:58', '2026-01-31 19:15:58'),
(2144, 'JXA', 'ZYJX', 'Jixi Xingkaihu Airport', NULL, 'CN', 'Heilongjiang', 45.2930000, 131.1930000, 'active', '2026-01-31 19:15:58', '2026-01-31 19:15:58'),
(2145, 'LDS', 'ZYLD', 'Yichun Lindu Airport', NULL, 'CN', 'Heilongjiang', 47.7521000, 129.0190000, 'active', '2026-01-31 19:15:58', '2026-01-31 19:15:58'),
(2146, 'MDG', 'ZYMD', 'Mudanjiang Hailang Airport', NULL, 'CN', 'Heilongjiang', 44.5241000, 129.5690000, 'active', '2026-01-31 19:15:59', '2026-01-31 19:15:59'),
(2147, 'NDG', 'ZYQQ', 'Qiqihar Sanjiazi Airport', NULL, 'CN', 'Heilongjiang', 47.2396000, 123.9180000, 'active', '2026-01-31 19:15:59', '2026-01-31 19:15:59'),
(2148, 'OHE', 'ZYMH', 'Mohe Gulian Airport', NULL, 'CN', 'Heilongjiang', 52.9128000, 122.4300000, 'active', '2026-01-31 19:16:00', '2026-01-31 19:16:00'),
(2149, 'YLN', 'ZYYL', 'Yilan Airport', NULL, 'CN', 'Heilongjiang', 46.3170000, 129.5670000, 'active', '2026-01-31 19:16:00', '2026-01-31 19:16:00'),
(2150, 'XAI', 'ZHXY', 'Xinyang Minggang Airport', NULL, 'CN', 'Henan Sheng', 32.5414000, 114.0780000, 'active', '2026-01-31 19:16:01', '2026-01-31 19:16:01'),
(2151, 'AYN', 'ZHAY', 'Anyang Airport', NULL, 'CN', 'Henan', 36.1339000, 114.3440000, 'active', '2026-01-31 19:16:03', '2026-01-31 19:16:03'),
(2152, 'CGO', 'ZHCC', 'Zhengzhou Xinzheng International Airport', NULL, 'CN', 'Henan', 34.5197000, 113.8410000, 'active', '2026-01-31 19:16:03', '2026-01-31 19:16:03'),
(2153, 'HQQ', NULL, 'Anyang Hongqiqu Airport', NULL, 'CN', 'Henan', 35.8706000, 114.4618000, 'active', '2026-01-31 19:16:03', '2026-01-31 19:16:03'),
(2154, 'HSJ', NULL, 'Zhengzhou Shangjie Airport', NULL, 'CN', 'Henan', 34.8422000, 113.2740000, 'active', '2026-01-31 19:16:04', '2026-01-31 19:16:04'),
(2155, 'LYA', 'ZHLY', 'Luoyang Beijiao Airport', NULL, 'CN', 'Henan', 34.7411000, 112.3880000, 'active', '2026-01-31 19:16:04', '2026-01-31 19:16:04'),
(2156, 'NNY', 'ZHNY', 'Nanyang Jiangying Airport', NULL, 'CN', 'Henan', 32.9808000, 112.6150000, 'active', '2026-01-31 19:16:05', '2026-01-31 19:16:05'),
(2157, 'EHU', 'ZHEC', 'Ezhou Huahu Airport', NULL, 'CN', 'Hubei Sheng', 30.3429000, 115.0300000, 'active', '2026-01-31 19:16:05', '2026-01-31 19:16:05'),
(2158, 'ENH', 'ZHES', 'Enshi Xujiaping Airport', NULL, 'CN', 'Hubei', 30.3203000, 109.4850000, 'active', '2026-01-31 19:16:05', '2026-01-31 19:16:05'),
(2159, 'HPG', 'ZHSN', 'Shennongjia Hongping Airport', NULL, 'CN', 'Hubei', 31.6260000, 110.3400000, 'active', '2026-01-31 19:16:06', '2026-01-31 19:16:06'),
(2160, 'LHK', 'ZHGH', 'Laohekou Airport', NULL, 'CN', 'Hubei', 32.3894000, 111.6950000, 'active', '2026-01-31 19:16:06', '2026-01-31 19:16:06'),
(2161, 'SHS', 'ZHSS', 'Shashi Airport', NULL, 'CN', 'Hubei', 30.3243000, 112.2800000, 'active', '2026-01-31 19:16:06', '2026-01-31 19:16:06'),
(2162, 'WDS', 'ZHSY', 'Shiyan Wudangshan Airport', NULL, 'CN', 'Hubei', 32.5917000, 110.9080000, 'active', '2026-01-31 19:16:07', '2026-01-31 19:16:07'),
(2163, 'WUH', 'ZHHH', 'Wuhan Tianhe International Airport', NULL, 'CN', 'Hubei', 30.7838000, 114.2080000, 'active', '2026-01-31 19:16:07', '2026-01-31 19:16:07'),
(2164, 'XFN', 'ZHXF', 'Xiangyang Liuji Airport', NULL, 'CN', 'Hubei', 32.1506000, 112.2910000, 'active', '2026-01-31 19:16:07', '2026-01-31 19:16:07'),
(2165, 'YIH', 'ZHYC', 'Yichang Sanxia Airport', NULL, 'CN', 'Hubei', 30.5565000, 111.4800000, 'active', '2026-01-31 19:16:08', '2026-01-31 19:16:08'),
(2166, 'HCZ', 'ZGCZ', 'Chenzhou Beihu Airport', NULL, 'CN', 'Hunan Sheng', 25.7506000, 112.8460000, 'active', '2026-01-31 19:16:08', '2026-01-31 19:16:08'),
(2167, 'YYA', 'ZGYY', 'Yueyang Sanhe Airport', NULL, 'CN', 'Hunan Sheng', 29.3140000, 113.2780000, 'active', '2026-01-31 19:16:08', '2026-01-31 19:16:08'),
(2168, 'CGD', 'ZGCD', 'Changde Taohuayuan Airport', NULL, 'CN', 'Hunan', 28.9189000, 111.6400000, 'active', '2026-01-31 19:16:09', '2026-01-31 19:16:09'),
(2169, 'CSX', 'ZGHA', 'Changsha Huanghua International Airport', NULL, 'CN', 'Hunan', 28.1892000, 113.2200000, 'active', '2026-01-31 19:16:09', '2026-01-31 19:16:09'),
(2170, 'DXJ', NULL, 'Xiangxi Biancheng Airport', NULL, 'CN', 'Hunan', 28.4963000, 109.5208000, 'active', '2026-01-31 19:16:09', '2026-01-31 19:16:09'),
(2171, 'DYG', 'ZGDY', 'Zhangjiajie Hehua Airport', NULL, 'CN', 'Hunan', 29.1028000, 110.4430000, 'active', '2026-01-31 19:16:10', '2026-01-31 19:16:10'),
(2172, 'HJJ', 'ZGCJ', 'Huaihua Zhijiang Airport', NULL, 'CN', 'Hunan', 27.4411000, 109.7000000, 'active', '2026-01-31 19:16:10', '2026-01-31 19:16:10'),
(2173, 'HNY', 'ZGHY', 'Hengyang Nanyue Airport', NULL, 'CN', 'Hunan', 26.9053000, 112.6280000, 'active', '2026-01-31 19:16:10', '2026-01-31 19:16:10'),
(2174, 'LLF', 'ZGLG', 'Yongzhou Lingling Airport', NULL, 'CN', 'Hunan', 26.3387000, 111.6100000, 'active', '2026-01-31 19:16:11', '2026-01-31 19:16:11'),
(2175, 'WGN', 'ZGSY', 'Shaoyang Wugang Airport', NULL, 'CN', 'Hunan', 26.8020000, 110.6420000, 'active', '2026-01-31 19:16:11', '2026-01-31 19:16:11'),
(2176, 'CZX', 'ZSCG', 'Changzhou Benniu Airport', NULL, 'CN', 'Jiangsu', 31.9197000, 119.7790000, 'active', '2026-01-31 19:16:11', '2026-01-31 19:16:11'),
(2177, 'HIA', 'ZSSH', 'Huai\'an Lianshui Airport', NULL, 'CN', 'Jiangsu', 33.7908000, 119.1250000, 'active', '2026-01-31 19:16:12', '2026-01-31 19:16:12'),
(2178, 'LYG', 'ZSLG', 'Lianyungang Baitabu Airport', NULL, 'CN', 'Jiangsu', 34.5717000, 118.8740000, 'active', '2026-01-31 19:16:12', '2026-01-31 19:16:12'),
(2179, 'NKG', 'ZSNJ', 'Nanjing Lukou International Airport', NULL, 'CN', 'Jiangsu', 31.7420000, 118.8620000, 'active', '2026-01-31 19:16:12', '2026-01-31 19:16:12'),
(2180, 'NTG', 'ZSNT', 'Nantong Xingdong Airport', NULL, 'CN', 'Jiangsu', 32.0708000, 120.9760000, 'active', '2026-01-31 19:16:13', '2026-01-31 19:16:13'),
(2181, 'RUG', 'ZSRG', 'Rugao Air Base', NULL, 'CN', 'Jiangsu', 32.2579000, 120.5020000, 'active', '2026-01-31 19:16:13', '2026-01-31 19:16:13'),
(2182, 'SZV', 'ZSSZ', 'Suzhou Guangfu Airport', NULL, 'CN', 'Jiangsu', 31.2631000, 120.4010000, 'active', '2026-01-31 19:16:13', '2026-01-31 19:16:13'),
(2183, 'WUX', 'ZSWX', 'Sunan Shuofang International Airport', NULL, 'CN', 'Jiangsu', 31.4944000, 120.4290000, 'active', '2026-01-31 19:16:14', '2026-01-31 19:16:14'),
(2184, 'XUZ', 'ZSXZ', 'Xuzhou Guanyin Airport', NULL, 'CN', 'Jiangsu', 34.0591000, 117.5550000, 'active', '2026-01-31 19:16:14', '2026-01-31 19:16:14'),
(2185, 'YNZ', 'ZSYN', 'Yancheng Nanyang International Airport', NULL, 'CN', 'Jiangsu', 33.4258000, 120.2030000, 'active', '2026-01-31 19:16:14', '2026-01-31 19:16:14'),
(2186, 'YTY', 'ZSYA', 'Yangzhou Taizhou Airport', NULL, 'CN', 'Jiangsu', 32.5602000, 119.7170000, 'active', '2026-01-31 19:16:15', '2026-01-31 19:16:15'),
(2187, 'JDZ', 'ZSJD', 'Jingdezhen Luojia Airport', NULL, 'CN', 'Jiangxi', 29.3386000, 117.1760000, 'active', '2026-01-31 19:16:15', '2026-01-31 19:16:15'),
(2188, 'JGS', 'ZSJA', 'Jinggangshan Airport', NULL, 'CN', 'Jiangxi', 26.8569000, 114.7370000, 'active', '2026-01-31 19:16:15', '2026-01-31 19:16:15'),
(2189, 'JIU', 'ZSJJ', 'Jiujiang Lushan Airport', NULL, 'CN', 'Jiangxi', 29.4769000, 115.8010000, 'active', '2026-01-31 19:16:16', '2026-01-31 19:16:16'),
(2190, 'KHN', 'ZSCN', 'Nanchang Changbei International Airport', NULL, 'CN', 'Jiangxi', 28.8650000, 115.9000000, 'active', '2026-01-31 19:16:16', '2026-01-31 19:16:16'),
(2191, 'KOW', 'ZSGZ', 'Ganzhou Huangjin Airport', NULL, 'CN', 'Jiangxi', 25.8533000, 114.7790000, 'active', '2026-01-31 19:16:16', '2026-01-31 19:16:16'),
(2192, 'SQD', 'ZSSR', 'Shangrao Sanqingshan Airport', NULL, 'CN', 'Jiangxi', 28.3797000, 117.9640000, 'active', '2026-01-31 19:16:17', '2026-01-31 19:16:17'),
(2193, 'YIC', 'ZSYC', 'Yichun Mingyueshan Airport', NULL, 'CN', 'Jiangxi', 27.8025000, 114.3060000, 'active', '2026-01-31 19:16:17', '2026-01-31 19:16:17'),
(2194, 'CGQ', 'ZYCC', 'Changchun Longjia International Airport', NULL, 'CN', 'Jilin', 43.9962000, 125.6850000, 'active', '2026-01-31 19:16:17', '2026-01-31 19:16:17'),
(2195, 'DBC', 'ZYBA', 'Baicheng Chang\'an Airport', NULL, 'CN', 'Jilin', 45.5053000, 123.0200000, 'active', '2026-01-31 19:16:18', '2026-01-31 19:16:18'),
(2196, 'JIL', 'ZYJL', 'Jilin Ertaizi Airport', NULL, 'CN', 'Jilin', 44.0022000, 126.3960000, 'active', '2026-01-31 19:16:18', '2026-01-31 19:16:18'),
(2197, 'NBS', 'ZYBS', 'Changbaishan Airport', NULL, 'CN', 'Jilin', 42.0669000, 127.6020000, 'active', '2026-01-31 19:16:19', '2026-01-31 19:16:19'),
(2198, 'TNH', 'ZYTN', 'Tonghua Sanyuanpu Airport', NULL, 'CN', 'Jilin', 42.2539000, 125.7030000, 'active', '2026-01-31 19:16:19', '2026-01-31 19:16:19'),
(2199, 'YNJ', 'ZYYJ', 'Yanji Chaoyangchuan Airport', NULL, 'CN', 'Jilin', 42.8828000, 129.4510000, 'active', '2026-01-31 19:16:20', '2026-01-31 19:16:20'),
(2200, 'YSQ', 'ZYSQ', 'Songyuan Chaganhu Airport', NULL, 'CN', 'Jilin', 44.9381000, 124.5500000, 'active', '2026-01-31 19:16:20', '2026-01-31 19:16:20'),
(2201, 'AOG', 'ZYAS', 'Anshan Teng\'ao Airport', NULL, 'CN', 'Liaoning', 41.1053000, 122.8540000, 'active', '2026-01-31 19:16:21', '2026-01-31 19:16:21'),
(2202, 'CHG', 'ZYCY', 'Chaoyang Airport', NULL, 'CN', 'Liaoning', 41.5381000, 120.4350000, 'active', '2026-01-31 19:16:21', '2026-01-31 19:16:21'),
(2203, 'CNI', 'ZYCH', 'Changhai Airport', NULL, 'CN', 'Liaoning', 39.2667000, 122.6670000, 'active', '2026-01-31 19:16:22', '2026-01-31 19:16:22'),
(2204, 'DDG', 'ZYDD', 'Dandong Langtou Airport', NULL, 'CN', 'Liaoning', 40.0247000, 124.2860000, 'active', '2026-01-31 19:16:22', '2026-01-31 19:16:22'),
(2205, 'DLC', 'ZYTL', 'Dalian Zhoushuizi International Airport', NULL, 'CN', 'Liaoning', 38.9657000, 121.5390000, 'active', '2026-01-31 19:16:22', '2026-01-31 19:16:22'),
(2206, 'JNZ', 'ZYJZ', 'Jinzhou Bay Airport', NULL, 'CN', 'Liaoning', 41.1014000, 121.0620000, 'active', '2026-01-31 19:16:23', '2026-01-31 19:16:23'),
(2207, 'SHE', 'ZYTX', 'Shenyang Taoxian International Airport', NULL, 'CN', 'Liaoning', 41.6398000, 123.4830000, 'active', '2026-01-31 19:16:23', '2026-01-31 19:16:23'),
(2208, 'XEN', 'ZYXC', 'Xingcheng Airport', NULL, 'CN', 'Liaoning', 40.5803000, 120.6980000, 'active', '2026-01-31 19:16:23', '2026-01-31 19:16:23'),
(2209, 'YKH', 'ZYYK', 'Yingkou Lanqi Airport', NULL, 'CN', 'Liaoning', 40.5425000, 122.3590000, 'active', '2026-01-31 19:16:24', '2026-01-31 19:16:24'),
(2210, 'AEQ', NULL, 'Ar Horqin Airport', NULL, 'CN', 'Nei Mongol', 43.8704000, 120.1600000, 'active', '2026-01-31 19:16:24', '2026-01-31 19:16:24'),
(2211, 'AXF', NULL, 'Alxa Left Banner Bayanhot Airport', NULL, 'CN', 'Nei Mongol', 38.7483000, 105.5890000, 'active', '2026-01-31 19:16:24', '2026-01-31 19:16:24'),
(2212, 'BAV', 'ZBOW', 'Baotou Airport', NULL, 'CN', 'Nei Mongol', 40.5600000, 109.9970000, 'active', '2026-01-31 19:16:25', '2026-01-31 19:16:25'),
(2213, 'CIF', 'ZBCF', 'Chifeng Yulong Airport', NULL, 'CN', 'Nei Mongol', 42.2350000, 118.9080000, 'active', '2026-01-31 19:16:25', '2026-01-31 19:16:25'),
(2214, 'DSN', 'ZBDS', 'Ordos Ejin Horo Airport', NULL, 'CN', 'Nei Mongol', 39.4900000, 109.8610000, 'active', '2026-01-31 19:16:25', '2026-01-31 19:16:25'),
(2215, 'EJN', NULL, 'Ejin Banner Taolai Airport', NULL, 'CN', 'Nei Mongol', 42.0155000, 101.0010000, 'active', '2026-01-31 19:16:26', '2026-01-31 19:16:26'),
(2216, 'ERL', 'ZBER', 'Erenhot Saiwusu International Airport', NULL, 'CN', 'Nei Mongol', 43.4225000, 112.0970000, 'active', '2026-01-31 19:16:26', '2026-01-31 19:16:26'),
(2217, 'HET', 'ZBHH', 'Hohhot Baita International Airport', NULL, 'CN', 'Nei Mongol', 40.8514000, 111.8240000, 'active', '2026-01-31 19:16:26', '2026-01-31 19:16:26'),
(2218, 'HLD', 'ZBLA', 'Hulunbuir Hailar Airport', NULL, 'CN', 'Nei Mongol', 49.2050000, 119.8250000, 'active', '2026-01-31 19:16:27', '2026-01-31 19:16:27'),
(2219, 'HLH', 'ZBUL', 'Ulanhot Airport', NULL, 'CN', 'Nei Mongol', 46.1953000, 122.0080000, 'active', '2026-01-31 19:16:27', '2026-01-31 19:16:27'),
(2220, 'HUO', 'ZBHZ', 'Holingol Huolinhe Airport', NULL, 'CN', 'Nei Mongol', 45.4872000, 119.4070000, 'active', '2026-01-31 19:16:27', '2026-01-31 19:16:27'),
(2221, 'NZH', 'ZBMZ', 'Manzhouli Xijiao Airport', NULL, 'CN', 'Nei Mongol', 49.5667000, 117.3300000, 'active', '2026-01-31 19:16:28', '2026-01-31 19:16:28'),
(2222, 'NZL', NULL, 'Zhalantun Chengjisihan Airport', NULL, 'CN', 'Nei Mongol', 47.8658000, 122.7680000, 'active', '2026-01-31 19:16:28', '2026-01-31 19:16:28'),
(2223, 'RHT', NULL, 'Alxa Right Banner Badanjilin Airport', NULL, 'CN', 'Nei Mongol', 39.2250000, 101.5460000, 'active', '2026-01-31 19:16:28', '2026-01-31 19:16:28'),
(2224, 'RLK', 'ZBYZ', 'Bayannur Tianjitai Airport', NULL, 'CN', 'Nei Mongol', 40.9260000, 107.7430000, 'active', '2026-01-31 19:16:29', '2026-01-31 19:16:29'),
(2225, 'TGO', 'ZBTL', 'Tongliao Airport', NULL, 'CN', 'Nei Mongol', 43.5567000, 122.2000000, 'active', '2026-01-31 19:16:29', '2026-01-31 19:16:29'),
(2226, 'UCB', NULL, 'Ulanqab Airport', NULL, 'CN', 'Nei Mongol', 41.1297000, 113.1080000, 'active', '2026-01-31 19:16:29', '2026-01-31 19:16:29'),
(2227, 'WUA', 'ZBUH', 'Wuhai Airport', NULL, 'CN', 'Nei Mongol', 39.7934000, 106.7990000, 'active', '2026-01-31 19:16:30', '2026-01-31 19:16:30'),
(2228, 'WZQ', NULL, 'Urad Middle Banner Airport', NULL, 'CN', 'Nei Mongol', 41.4596000, 108.5350000, 'active', '2026-01-31 19:16:30', '2026-01-31 19:16:30'),
(2229, 'XIL', 'ZBXH', 'Xilinhot Airport', NULL, 'CN', 'Nei Mongol', 43.9156000, 115.9640000, 'active', '2026-01-31 19:16:30', '2026-01-31 19:16:30'),
(2230, 'YIE', 'ZBES', 'Arxan Yi\'ershi Airport', NULL, 'CN', 'Nei Mongol', 47.3106000, 119.9120000, 'active', '2026-01-31 19:16:31', '2026-01-31 19:16:31'),
(2231, 'GYU', 'ZLGY', 'Guyuan Liupanshan Airport', NULL, 'CN', 'Ningxia', 36.0789000, 106.2170000, 'active', '2026-01-31 19:16:31', '2026-01-31 19:16:31'),
(2232, 'INC', 'ZLIC', 'Yinchuan Hedong International Airport', NULL, 'CN', 'Ningxia', 38.3228000, 106.3930000, 'active', '2026-01-31 19:16:31', '2026-01-31 19:16:31'),
(2233, 'ZHY', 'ZLZW', 'Zhongwei Shapotou Airport (Zhongwei Xiangshan Airport)', NULL, 'CN', 'Ningxia', 37.5731000, 105.1540000, 'active', '2026-01-31 19:16:32', '2026-01-31 19:16:32'),
(2234, 'HBQ', 'ZLHB', 'Haibei Qilian Airport', NULL, 'CN', 'Qinghai Sheng', 38.0120000, 100.6440000, 'active', '2026-01-31 19:16:32', '2026-01-31 19:16:32'),
(2235, 'GMQ', 'ZLGL', 'Golog Maqin Airport', NULL, 'CN', 'Qinghai', 34.4181000, 100.3010000, 'active', '2026-01-31 19:16:32', '2026-01-31 19:16:32'),
(2236, 'GOQ', 'ZLGM', 'Golmud Airport', NULL, 'CN', 'Qinghai', 36.4006000, 94.7861000, 'active', '2026-01-31 19:16:33', '2026-01-31 19:16:33'),
(2237, 'HTT', NULL, 'Huatugou Airport', NULL, 'CN', 'Qinghai', 38.2020000, 90.8415000, 'active', '2026-01-31 19:16:33', '2026-01-31 19:16:33'),
(2238, 'HXD', 'ZLDL', 'Delingha Airport', NULL, 'CN', 'Qinghai', 37.1253000, 97.2687000, 'active', '2026-01-31 19:16:33', '2026-01-31 19:16:33'),
(2239, 'XNN', 'ZLXN', 'Xining Caojiabao Airport', NULL, 'CN', 'Qinghai', 36.5275000, 102.0430000, 'active', '2026-01-31 19:16:34', '2026-01-31 19:16:34'),
(2240, 'YUS', 'ZLYS', 'Yushu Batang Airport', NULL, 'CN', 'Qinghai', 32.8364000, 97.0364000, 'active', '2026-01-31 19:16:34', '2026-01-31 19:16:34'),
(2241, 'AKA', 'ZLAK', 'Ankang Wulipu Airport', NULL, 'CN', 'Shaanxi', 32.7081000, 108.9310000, 'active', '2026-01-31 19:16:34', '2026-01-31 19:16:34'),
(2242, 'ENY', 'ZLYA', 'Yan\'an Nanniwan (formerly Ershilipu) Airport', NULL, 'CN', 'Shaanxi', 36.6369000, 109.5540000, 'active', '2026-01-31 19:16:35', '2026-01-31 19:16:35'),
(2243, 'HZG', 'ZLHZ', 'Hanzhong Chenggu Airport', NULL, 'CN', 'Shaanxi', 33.1341000, 107.2060000, 'active', '2026-01-31 19:16:36', '2026-01-31 19:16:36'),
(2244, 'SIA', 'ZLSN', 'Xi\'an Xiguan Airport', NULL, 'CN', 'Shaanxi', 34.3767000, 109.1200000, 'active', '2026-01-31 19:16:37', '2026-01-31 19:16:37'),
(2245, 'UYN', 'ZLYL', 'Yulin Yuyang Airport', NULL, 'CN', 'Shaanxi', 38.3597000, 109.5910000, 'active', '2026-01-31 19:16:37', '2026-01-31 19:16:37'),
(2246, 'XIY', 'ZLXY', 'Xi\'an Xianyang International Airport', NULL, 'CN', 'Shaanxi', 34.4471000, 108.7520000, 'active', '2026-01-31 19:16:37', '2026-01-31 19:16:37'),
(2247, 'HZA', 'ZSHZ', 'Heze Mudan Airport', NULL, 'CN', 'Shandong Sheng', 35.2133000, 115.7370000, 'active', '2026-01-31 19:16:38', '2026-01-31 19:16:38'),
(2248, 'DOY', 'ZSDY', 'Dongying Shengli Airport', NULL, 'CN', 'Shandong', 37.5086000, 118.7880000, 'active', '2026-01-31 19:16:38', '2026-01-31 19:16:38'),
(2249, 'JNG', 'ZLJN', 'Jining Qufu Airport', NULL, 'CN', 'Shandong', 35.2928000, 116.3470000, 'active', '2026-01-31 19:16:38', '2026-01-31 19:16:38'),
(2250, 'LYI', 'ZSLY', 'Linyi Shubuling Airport', NULL, 'CN', 'Shandong', 35.0461000, 118.4120000, 'active', '2026-01-31 19:16:39', '2026-01-31 19:16:39'),
(2251, 'PNJ', NULL, 'Penglai Shahekou Airport', NULL, 'CN', 'Shandong', 42.4464000, 119.5740000, 'active', '2026-01-31 19:16:39', '2026-01-31 19:16:39'),
(2252, 'RIZ', NULL, 'Rizhao Shanzihe Airport', NULL, 'CN', 'Shandong', 35.4050000, 119.3240000, 'active', '2026-01-31 19:16:39', '2026-01-31 19:16:39'),
(2253, 'TAO', 'ZSQD', 'Qingdao Liuting International Airport', NULL, 'CN', 'Shandong', 36.2661000, 120.3740000, 'active', '2026-01-31 19:16:40', '2026-01-31 19:16:40'),
(2254, 'TNA', 'ZSJN', 'Jinan Yaoqiang International Airport', NULL, 'CN', 'Shandong', 36.8572000, 117.2160000, 'active', '2026-01-31 19:16:40', '2026-01-31 19:16:40'),
(2255, 'WEF', 'ZSWF', 'Weifang Airport', NULL, 'CN', 'Shandong', 36.6467000, 119.1190000, 'active', '2026-01-31 19:16:40', '2026-01-31 19:16:40'),
(2256, 'WEH', 'ZSWH', 'Weihai Dashuibo Airport', NULL, 'CN', 'Shandong', 37.1871000, 122.2290000, 'active', '2026-01-31 19:16:41', '2026-01-31 19:16:41'),
(2257, 'YNT', 'ZSYT', 'Yantai Penglai International Airport', NULL, 'CN', 'Shandong', 37.6572000, 120.9870000, 'active', '2026-01-31 19:16:41', '2026-01-31 19:16:41'),
(2258, 'PVG', 'ZSPD', 'Shanghai Pudong International Airport', NULL, 'CN', 'Shanghai', 31.1434000, 121.8050000, 'active', '2026-01-31 19:16:41', '2026-01-31 19:16:41');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(2259, 'SHA', 'ZSSS', 'Shanghai Hongqiao International Airport', NULL, 'CN', 'Shanghai', 31.1979000, 121.3360000, 'active', '2026-01-31 19:16:42', '2026-01-31 19:16:42'),
(2260, 'CIH', 'ZBCZ', 'Changzhi Wangcun Airport', NULL, 'CN', 'Shanxi', 36.2475000, 113.1260000, 'active', '2026-01-31 19:16:42', '2026-01-31 19:16:42'),
(2261, 'DAT', 'ZBDT', 'Datong Yungang Airport', NULL, 'CN', 'Shanxi', 40.0603000, 113.4820000, 'active', '2026-01-31 19:16:42', '2026-01-31 19:16:42'),
(2262, 'LFQ', NULL, 'Linfen Qiaoli Airport', NULL, 'CN', 'Shanxi', 36.1326000, 111.6410000, 'active', '2026-01-31 19:16:43', '2026-01-31 19:16:43'),
(2263, 'LLV', 'ZBLL', 'Luliang Airport', NULL, 'CN', 'Shanxi', 37.6833000, 111.1430000, 'active', '2026-01-31 19:16:43', '2026-01-31 19:16:43'),
(2264, 'SZH', 'ZBSG', 'Shuozhou Zirun Airport', NULL, 'CN', 'Shanxi', 39.2730000, 112.6911000, 'active', '2026-01-31 19:16:44', '2026-01-31 19:16:44'),
(2265, 'TYN', 'ZBYN', 'Taiyuan Wusu International Airport', NULL, 'CN', 'Shanxi', 37.7469000, 112.6280000, 'active', '2026-01-31 19:16:44', '2026-01-31 19:16:44'),
(2266, 'WUT', 'ZBXZ', 'Xinzhou Wutaishan Airport', NULL, 'CN', 'Shanxi', 38.5975000, 112.9690000, 'active', '2026-01-31 19:16:44', '2026-01-31 19:16:44'),
(2267, 'YCU', 'ZBYC', 'Yuncheng Guangong Airport', NULL, 'CN', 'Shanxi', 35.1164000, 111.0310000, 'active', '2026-01-31 19:16:45', '2026-01-31 19:16:45'),
(2268, 'DZH', 'ZUDA', 'Dazhou Jinya Airport', NULL, 'CN', 'Sichuan Sheng', 31.0400000, 107.4400000, 'active', '2026-01-31 19:16:45', '2026-01-31 19:16:45'),
(2269, 'AHJ', 'ZUHY', 'Hongyuan Airport', NULL, 'CN', 'Sichuan', 32.5315000, 102.3520000, 'active', '2026-01-31 19:16:45', '2026-01-31 19:16:45'),
(2270, 'BZX', NULL, 'Bazhong Enyang Airport', NULL, 'CN', 'Sichuan', 31.7384000, 106.6450000, 'active', '2026-01-31 19:16:46', '2026-01-31 19:16:46'),
(2271, 'CTU', 'ZUUU', 'Chengdu Shuangliu International Airport', NULL, 'CN', 'Sichuan', 30.5785000, 103.9470000, 'active', '2026-01-31 19:16:46', '2026-01-31 19:16:46'),
(2272, 'DAX', 'ZUDX', 'Dazhou Heshi Airport', NULL, 'CN', 'Sichuan', 31.1302000, 107.4290000, 'active', '2026-01-31 19:16:46', '2026-01-31 19:16:46'),
(2273, 'DCY', 'ZUDC', 'Daocheng Yading Airport', NULL, 'CN', 'Sichuan', 29.3231000, 100.0530000, 'active', '2026-01-31 19:16:47', '2026-01-31 19:16:47'),
(2274, 'GHN', 'ZUGH', 'Guanghan Airport', NULL, 'CN', 'Sichuan', 30.9485000, 104.3300000, 'active', '2026-01-31 19:16:47', '2026-01-31 19:16:47'),
(2275, 'GYS', 'ZUGU', 'Guangyuan Panlong Airport', NULL, 'CN', 'Sichuan', 32.3911000, 105.7020000, 'active', '2026-01-31 19:16:47', '2026-01-31 19:16:47'),
(2276, 'GZG', 'ZUGZ', 'Garze Gesar Airport', NULL, 'CN', 'Sichuan', 31.7579000, 99.5525000, 'active', '2026-01-31 19:16:48', '2026-01-31 19:16:48'),
(2277, 'JZH', 'ZUJZ', 'Jiuzhai Huanglong Airport', NULL, 'CN', 'Sichuan', 32.8533000, 103.6820000, 'active', '2026-01-31 19:16:48', '2026-01-31 19:16:48'),
(2278, 'KGT', 'ZUKD', 'Kangding Airport', NULL, 'CN', 'Sichuan', 30.1575000, 101.7350000, 'active', '2026-01-31 19:16:48', '2026-01-31 19:16:48'),
(2279, 'LZG', NULL, 'Langzhong Gucheng Airport', NULL, 'CN', 'Sichuan', 31.5077000, 106.0426000, 'active', '2026-01-31 19:16:49', '2026-01-31 19:16:49'),
(2280, 'LZO', 'ZULZ', 'Luzhou Yunlong Airport', NULL, 'CN', 'Sichuan', 29.0300000, 105.4700000, 'active', '2026-01-31 19:16:49', '2026-01-31 19:16:49'),
(2281, 'MIG', 'ZUMY', 'Mianyang Nanjiao Airport', NULL, 'CN', 'Sichuan', 31.4281000, 104.7410000, 'active', '2026-01-31 19:16:49', '2026-01-31 19:16:49'),
(2282, 'NAO', 'ZUNC', 'Nanchong Gaoping Airport', NULL, 'CN', 'Sichuan', 30.7955000, 106.1630000, 'active', '2026-01-31 19:16:50', '2026-01-31 19:16:50'),
(2283, 'PZI', 'ZUZH', 'Panzhihua Bao\'anying Airport', NULL, 'CN', 'Sichuan', 26.5400000, 101.7990000, 'active', '2026-01-31 19:16:50', '2026-01-31 19:16:50'),
(2284, 'TFU', 'ZUTF', 'Chengdu Tianfu International Airport', NULL, 'CN', 'Sichuan', 30.3190000, 104.4450000, 'active', '2026-01-31 19:16:50', '2026-01-31 19:16:50'),
(2285, 'XIC', 'ZUXC', 'Xichang Qingshan Airport', NULL, 'CN', 'Sichuan', 27.9891000, 102.1840000, 'active', '2026-01-31 19:16:51', '2026-01-31 19:16:51'),
(2286, 'YBP', 'ZUYB', 'Yibin Caiba Airport', NULL, 'CN', 'Sichuan', 28.8006000, 104.5450000, 'active', '2026-01-31 19:16:51', '2026-01-31 19:16:51'),
(2287, 'TSN', 'ZBTJ', 'Tianjin Binhai International Airport', NULL, 'CN', 'Tianjin', 39.1244000, 117.3460000, 'active', '2026-01-31 19:16:51', '2026-01-31 19:16:51'),
(2288, 'AAT', 'ZWAT', 'Altay Airport', NULL, 'CN', 'Xinjiang', 47.7499000, 88.0858000, 'active', '2026-01-31 19:16:52', '2026-01-31 19:16:52'),
(2289, 'ACF', NULL, 'Aral Talim Airport', NULL, 'CN', 'Xinjiang', 40.4394000, 81.2601000, 'active', '2026-01-31 19:16:52', '2026-01-31 19:16:52'),
(2290, 'AKU', 'ZWAK', 'Aksu Airport', NULL, 'CN', 'Xinjiang', 41.2625000, 80.2917000, 'active', '2026-01-31 19:16:52', '2026-01-31 19:16:52'),
(2291, 'BPL', 'ZWBL', 'Bole Alashankou Airport', NULL, 'CN', 'Xinjiang', 44.8950000, 82.3000000, 'active', '2026-01-31 19:16:53', '2026-01-31 19:16:53'),
(2292, 'FYN', 'ZWFY', 'Fuyun Koktokay Airport', NULL, 'CN', 'Xinjiang', 46.8042000, 89.5120000, 'active', '2026-01-31 19:16:53', '2026-01-31 19:16:53'),
(2293, 'HMI', 'ZWHM', 'Hami Airport (Kumul Airport)', NULL, 'CN', 'Xinjiang', 42.8414000, 93.6692000, 'active', '2026-01-31 19:16:53', '2026-01-31 19:16:53'),
(2294, 'HQL', NULL, 'Tashkurgan Khunjerab Airport', NULL, 'CN', 'Xinjiang', 37.6628000, 75.2920000, 'active', '2026-01-31 19:16:54', '2026-01-31 19:16:54'),
(2295, 'HTN', 'ZWTN', 'Hotan Airport', NULL, 'CN', 'Xinjiang', 37.0385000, 79.8649000, 'active', '2026-01-31 19:16:54', '2026-01-31 19:16:54'),
(2296, 'IQM', 'ZWCM', 'Qiemo Airport', NULL, 'CN', 'Xinjiang', 38.2336000, 85.4656000, 'active', '2026-01-31 19:16:54', '2026-01-31 19:16:54'),
(2297, 'JBK', NULL, 'Qitai Jiangbulake Airport (formerly Berkeley)', NULL, 'CN', 'Xinjiang', 44.1830000, 89.5945000, 'active', '2026-01-31 19:16:55', '2026-01-31 19:16:55'),
(2298, 'KCA', 'ZWKC', 'Kuqa Qiuci Airport', NULL, 'CN', 'Xinjiang', 41.6779000, 82.8729000, 'active', '2026-01-31 19:16:55', '2026-01-31 19:16:55'),
(2299, 'KHG', 'ZWSH', 'Kashgar Airport (Kashi Airport)', NULL, 'CN', 'Xinjiang', 39.5429000, 76.0200000, 'active', '2026-01-31 19:16:55', '2026-01-31 19:16:55'),
(2300, 'KJI', 'ZWKN', 'Kanas Airport', NULL, 'CN', 'Xinjiang', 48.2223000, 86.9959000, 'active', '2026-01-31 19:16:56', '2026-01-31 19:16:56'),
(2301, 'KRL', 'ZWKL', 'Korla Airport', NULL, 'CN', 'Xinjiang', 41.6978000, 86.1289000, 'active', '2026-01-31 19:16:56', '2026-01-31 19:16:56'),
(2302, 'KRY', 'ZWKM', 'Karamay Airport', NULL, 'CN', 'Xinjiang', 45.4665000, 84.9527000, 'active', '2026-01-31 19:16:56', '2026-01-31 19:16:56'),
(2303, 'NLT', 'ZWNL', 'Xinyuan Nalati Airport', NULL, 'CN', 'Xinjiang', 43.4318000, 83.3786000, 'active', '2026-01-31 19:16:57', '2026-01-31 19:16:57'),
(2304, 'QSZ', NULL, 'Shache Airport', NULL, 'CN', 'Xinjiang', 38.2811000, 77.0752000, 'active', '2026-01-31 19:16:57', '2026-01-31 19:16:57'),
(2305, 'RQA', 'ZWRQ', 'Ruoqiang Loulan Airport', NULL, 'CN', 'Xinjiang', 38.9747000, 88.0083000, 'active', '2026-01-31 19:16:57', '2026-01-31 19:16:57'),
(2306, 'SHF', 'ZWHZ', 'Shihezi Huayuan Airport', NULL, 'CN', 'Xinjiang', 44.2421000, 85.8905000, 'active', '2026-01-31 19:16:58', '2026-01-31 19:16:58'),
(2307, 'SXJ', 'ZWSS', 'Shanshan Airport', NULL, 'CN', 'Xinjiang', 42.9117000, 90.2475000, 'active', '2026-01-31 19:16:58', '2026-01-31 19:16:58'),
(2308, 'TCG', 'ZWTC', 'Tacheng Airport', NULL, 'CN', 'Xinjiang', 46.6725000, 83.3408000, 'active', '2026-01-31 19:16:58', '2026-01-31 19:16:58'),
(2309, 'TLQ', 'ZWTL', 'Turpan Jiaohe Airport', NULL, 'CN', 'Xinjiang', 43.0308000, 89.0987000, 'active', '2026-01-31 19:16:59', '2026-01-31 19:16:59'),
(2310, 'TWC', NULL, 'Tumushuke Tangwangcheng Airport', NULL, 'CN', 'Xinjiang', 39.8893000, 79.2322000, 'active', '2026-01-31 19:16:59', '2026-01-31 19:16:59'),
(2311, 'URC', 'ZWWW', 'Urumqi Diwopu International Airport', NULL, 'CN', 'Xinjiang', 43.9071000, 87.4742000, 'active', '2026-01-31 19:16:59', '2026-01-31 19:16:59'),
(2312, 'YIN', 'ZWYN', 'Yining Airport', NULL, 'CN', 'Xinjiang', 43.9558000, 81.3303000, 'active', '2026-01-31 19:17:00', '2026-01-31 19:17:00'),
(2313, 'YTW', 'ZWYT', 'Yutian Wanfang Airport', NULL, 'CN', 'Xinjiang', 36.8120000, 81.7817000, 'active', '2026-01-31 19:17:00', '2026-01-31 19:17:00'),
(2314, 'ZFL', NULL, 'Zhaosu Tianma Airport', NULL, 'CN', 'Xinjiang', 43.0927000, 81.2247000, 'active', '2026-01-31 19:17:00', '2026-01-31 19:17:00'),
(2315, 'BPX', 'ZUBD', 'Qamdo Bamda Airport', NULL, 'CN', 'Xizang', 30.5536000, 97.1083000, 'active', '2026-01-31 19:17:01', '2026-01-31 19:17:01'),
(2316, 'DDR', NULL, 'Xigaze/Rikaze Dingri Airport', NULL, 'CN', 'Xizang', 28.6014000, 86.8018000, 'active', '2026-01-31 19:17:01', '2026-01-31 19:17:01'),
(2317, 'LGZ', NULL, 'Shannan Lizang Airport', NULL, 'CN', 'Xizang', 28.4275000, 92.3447000, 'active', '2026-01-31 19:17:01', '2026-01-31 19:17:01'),
(2318, 'LXA', 'ZULS', 'Lhasa Gonggar Airport', NULL, 'CN', 'Xizang', 29.2978000, 90.9119000, 'active', '2026-01-31 19:17:02', '2026-01-31 19:17:02'),
(2319, 'LZY', 'ZUNZ', 'Nyingchi Mainling Airport', NULL, 'CN', 'Xizang', 29.3033000, 94.3353000, 'active', '2026-01-31 19:17:02', '2026-01-31 19:17:02'),
(2320, 'NGQ', 'ZUAL', 'Ngari Gunsa Airport', NULL, 'CN', 'Xizang', 32.1000000, 80.0531000, 'active', '2026-01-31 19:17:02', '2026-01-31 19:17:02'),
(2321, 'RKZ', 'ZURK', 'Shigatse Peace Airport', NULL, 'CN', 'Xizang', 29.3519000, 89.3114000, 'active', '2026-01-31 19:17:03', '2026-01-31 19:17:03'),
(2322, 'BSD', 'ZPBS', 'Baoshan Yunduan Airport', NULL, 'CN', 'Yunnan', 25.0533000, 99.1683000, 'active', '2026-01-31 19:17:03', '2026-01-31 19:17:03'),
(2323, 'CWJ', 'ZPCW', 'Cangyuan Washan Airport', NULL, 'CN', 'Yunnan', 23.2739000, 99.3736000, 'active', '2026-01-31 19:17:03', '2026-01-31 19:17:03'),
(2324, 'DIG', 'ZPDQ', 'Diqing Shangri-La Airport', NULL, 'CN', 'Yunnan', 27.7936000, 99.6772000, 'active', '2026-01-31 19:17:04', '2026-01-31 19:17:04'),
(2325, 'DLU', 'ZPDL', 'Dali Airport', NULL, 'CN', 'Yunnan', 25.6494000, 100.3190000, 'active', '2026-01-31 19:17:04', '2026-01-31 19:17:04'),
(2326, 'JHG', 'ZPJH', 'Xishuangbanna Gasa Airport', NULL, 'CN', 'Yunnan', 21.9739000, 100.7600000, 'active', '2026-01-31 19:17:04', '2026-01-31 19:17:04'),
(2327, 'JMJ', 'ZPJM', 'Lancang Jingmai Airport', NULL, 'CN', 'Yunnan', 22.4158000, 99.7864000, 'active', '2026-01-31 19:17:05', '2026-01-31 19:17:05'),
(2328, 'KMG', 'ZPPP', 'Kunming Changshui International Airport', NULL, 'CN', 'Yunnan', 25.1019000, 102.9290000, 'active', '2026-01-31 19:17:05', '2026-01-31 19:17:05'),
(2329, 'LJG', 'ZPLJ', 'Lijiang Sanyi Airport', NULL, 'CN', 'Yunnan', 26.6800000, 100.2460000, 'active', '2026-01-31 19:17:05', '2026-01-31 19:17:05'),
(2330, 'LNJ', 'ZPLC', 'Lincang Airport', NULL, 'CN', 'Yunnan', 23.7381000, 100.0250000, 'active', '2026-01-31 19:17:06', '2026-01-31 19:17:06'),
(2331, 'LUM', 'ZPMS', 'Dehong Mangshi Airport', NULL, 'CN', 'Yunnan', 24.4011000, 98.5317000, 'active', '2026-01-31 19:17:06', '2026-01-31 19:17:06'),
(2332, 'NLH', NULL, 'Ninglang Luguhu Airport', NULL, 'CN', 'Yunnan', 27.5403000, 100.7590000, 'active', '2026-01-31 19:17:06', '2026-01-31 19:17:06'),
(2333, 'SYM', 'ZPSM', 'Pu\'er Simao Airport', NULL, 'CN', 'Yunnan', 22.7933000, 100.9590000, 'active', '2026-01-31 19:17:07', '2026-01-31 19:17:07'),
(2334, 'TCZ', 'ZUTC', 'Tengchong Tuofeng Airport', NULL, 'CN', 'Yunnan', 24.9381000, 98.4858000, 'active', '2026-01-31 19:17:07', '2026-01-31 19:17:07'),
(2335, 'WNH', 'ZPWS', 'Wenshan Puzhehei Airport', NULL, 'CN', 'Yunnan', 23.5583000, 104.3260000, 'active', '2026-01-31 19:17:07', '2026-01-31 19:17:07'),
(2336, 'YUA', 'ZPYM', 'Yuanmou Air Base', NULL, 'CN', 'Yunnan', 25.7375000, 101.8820000, 'active', '2026-01-31 19:17:08', '2026-01-31 19:17:08'),
(2337, 'ZAT', 'ZPZT', 'Zhaotong Airport', NULL, 'CN', 'Yunnan', 27.3256000, 103.7550000, 'active', '2026-01-31 19:17:08', '2026-01-31 19:17:08'),
(2338, 'HGH', 'ZSHC', 'Hangzhou Xiaoshan International Airport', NULL, 'CN', 'Zhejiang', 30.2295000, 120.4340000, 'active', '2026-01-31 19:17:08', '2026-01-31 19:17:08'),
(2339, 'HSN', 'ZSZS', 'Zhoushan Putuoshan Airport', NULL, 'CN', 'Zhejiang', 29.9342000, 122.3620000, 'active', '2026-01-31 19:17:09', '2026-01-31 19:17:09'),
(2340, 'HYN', 'ZSLQ', 'Taizhou Luqiao Airport', NULL, 'CN', 'Zhejiang', 28.5622000, 121.4290000, 'active', '2026-01-31 19:17:09', '2026-01-31 19:17:09'),
(2341, 'JUZ', 'ZSJU', 'Quzhou Airport', NULL, 'CN', 'Zhejiang', 28.9658000, 118.8990000, 'active', '2026-01-31 19:17:09', '2026-01-31 19:17:09'),
(2342, 'NGB', 'ZSNB', 'Ningbo Lishe International Airport', NULL, 'CN', 'Zhejiang', 29.8267000, 121.4620000, 'active', '2026-01-31 19:17:10', '2026-01-31 19:17:10'),
(2343, 'WNZ', 'ZSWZ', 'Wenzhou Longwan International Airport', NULL, 'CN', 'Zhejiang', 27.9122000, 120.8520000, 'active', '2026-01-31 19:17:10', '2026-01-31 19:17:10'),
(2344, 'YIW', 'ZSYW', 'Yiwu Airport', NULL, 'CN', 'Zhejiang', 29.3447000, 120.0320000, 'active', '2026-01-31 19:17:10', '2026-01-31 19:17:10'),
(2345, 'ACM', NULL, 'Arica Airport (Colombia)', NULL, 'CO', 'Amazonas', -2.1454400, -71.7581000, 'active', '2026-01-31 19:17:11', '2026-01-31 19:17:11'),
(2346, 'AYC', NULL, 'Ayacucho Airport', NULL, 'CO', 'Amazonas', 8.6000000, -73.6167000, 'active', '2026-01-31 19:17:11', '2026-01-31 19:17:11'),
(2347, 'ECO', NULL, 'El Encanto Airport', NULL, 'CO', 'Amazonas', -1.7533300, -73.2047000, 'active', '2026-01-31 19:17:11', '2026-01-31 19:17:11'),
(2348, 'LCR', NULL, 'La Chorrera Airport', NULL, 'CO', 'Amazonas', -0.7333330, -73.0167000, 'active', '2026-01-31 19:17:12', '2026-01-31 19:17:12'),
(2349, 'LET', 'SKLT', 'Alfredo Vasquez Cobo International Airport', NULL, 'CO', 'Amazonas', -4.1935500, -69.9432000, 'active', '2026-01-31 19:17:12', '2026-01-31 19:17:12'),
(2350, 'LPD', 'SKLP', 'La Pedrera Airport', NULL, 'CO', 'Amazonas', -1.3286100, -69.5797000, 'active', '2026-01-31 19:17:12', '2026-01-31 19:17:12'),
(2351, 'SSD', 'SCSF', 'San Felipe Airport', NULL, 'CO', 'Amazonas', -32.7458000, -70.7050000, 'active', '2026-01-31 19:17:13', '2026-01-31 19:17:13'),
(2352, 'TCD', 'SKRA', 'Tarapaca Airport', NULL, 'CO', 'Amazonas', -2.8947200, -69.7472000, 'active', '2026-01-31 19:17:13', '2026-01-31 19:17:13'),
(2353, 'ADN', 'SKAN', 'Andes Airport', NULL, 'CO', 'Antioquia', 5.6976400, -75.8804000, 'active', '2026-01-31 19:17:13', '2026-01-31 19:17:13'),
(2354, 'AFI', 'SKAM', 'Amalfi Airport (Colombia)', NULL, 'CO', 'Antioquia', 6.9166700, -75.0667000, 'active', '2026-01-31 19:17:14', '2026-01-31 19:17:14'),
(2355, 'APO', 'SKLC', 'Antonio Roldan  Betancourt Airport', NULL, 'CO', 'Antioquia', 7.8119600, -76.7164000, 'active', '2026-01-31 19:17:14', '2026-01-31 19:17:14'),
(2356, 'ARO', NULL, 'Arboletes Airport', NULL, 'CO', 'Antioquia', 8.8570500, -76.4244000, 'active', '2026-01-31 19:17:14', '2026-01-31 19:17:14'),
(2357, 'CAQ', 'SKCU', 'Juan H. White Airport', NULL, 'CO', 'Antioquia', 7.9684700, -75.1985000, 'active', '2026-01-31 19:17:15', '2026-01-31 19:17:15'),
(2358, 'EBG', 'SKEB', 'El Bagre Airport (El Tomin Airport)', NULL, 'CO', 'Antioquia', 7.5964700, -74.8089000, 'active', '2026-01-31 19:17:15', '2026-01-31 19:17:15'),
(2359, 'EOH', 'SKMD', 'Olaya Herrera Airport', NULL, 'CO', 'Antioquia', 6.2205500, -75.5906000, 'active', '2026-01-31 19:17:15', '2026-01-31 19:17:15'),
(2360, 'IGO', 'SKIG', 'Jaime Ortiz Betancur Airport', NULL, 'CO', 'Antioquia', 7.6803800, -76.6865000, 'active', '2026-01-31 19:17:16', '2026-01-31 19:17:16'),
(2361, 'MDE', 'SKRG', 'Jose Maria Cordova International Airport', NULL, 'CO', 'Antioquia', 6.1645400, -75.4231000, 'active', '2026-01-31 19:17:16', '2026-01-31 19:17:16'),
(2362, 'NAR', 'SKPN', 'Puerto Nare Airport', NULL, 'CO', 'Antioquia', 6.2100200, -74.5906000, 'active', '2026-01-31 19:17:16', '2026-01-31 19:17:16'),
(2363, 'NCI', 'SKNC', 'Antioquia Airport', NULL, 'CO', 'Antioquia', 8.4500000, -76.7833000, 'active', '2026-01-31 19:17:17', '2026-01-31 19:17:17'),
(2364, 'NPU', NULL, 'San Pedro de Uraba Airport', NULL, 'CO', 'Antioquia', 8.2859700, -76.3804000, 'active', '2026-01-31 19:17:17', '2026-01-31 19:17:17'),
(2365, 'OTU', 'SKOT', 'Otu Airport', NULL, 'CO', 'Antioquia', 7.0103700, -74.7155000, 'active', '2026-01-31 19:17:18', '2026-01-31 19:17:18'),
(2366, 'PBE', 'SKPR', 'Morela Airport (Puerto Berrio Airport', NULL, 'CO', 'Antioquia', 6.4603400, -74.4105000, 'active', '2026-01-31 19:17:18', '2026-01-31 19:17:18'),
(2367, 'SJR', NULL, 'San Juan de Uraba Airport', NULL, 'CO', 'Antioquia', 8.7666700, -76.5333000, 'active', '2026-01-31 19:17:19', '2026-01-31 19:17:19'),
(2368, 'SMC', NULL, 'Santa Maria Airport', NULL, 'CO', 'Antioquia', 8.1500000, -77.0500000, 'active', '2026-01-31 19:17:19', '2026-01-31 19:17:19'),
(2369, 'TRB', 'SKTU', 'Gonzalo Mejia Airport', NULL, 'CO', 'Antioquia', 8.0745300, -76.7415000, 'active', '2026-01-31 19:17:19', '2026-01-31 19:17:19'),
(2370, 'ULS', NULL, 'Mulatos Airport', NULL, 'CO', 'Antioquia', 8.6500000, -76.7500000, 'active', '2026-01-31 19:17:20', '2026-01-31 19:17:20'),
(2371, 'UNC', NULL, 'Unguia Airport', NULL, 'CO', 'Antioquia', 8.0333300, -77.0833000, 'active', '2026-01-31 19:17:20', '2026-01-31 19:17:20'),
(2372, 'URR', 'SKUR', 'Urrao Airport', NULL, 'CO', 'Antioquia', 6.3288300, -76.1425000, 'active', '2026-01-31 19:17:20', '2026-01-31 19:17:20'),
(2373, 'ARQ', 'SKAT', 'El Troncal Airport', NULL, 'CO', 'Arauca', 7.0210600, -71.3889000, 'active', '2026-01-31 19:17:21', '2026-01-31 19:17:21'),
(2374, 'AUC', 'SKUC', 'Santiago Perez  Quiroz Airport', NULL, 'CO', 'Arauca', 7.0688800, -70.7369000, 'active', '2026-01-31 19:17:21', '2026-01-31 19:17:21'),
(2375, 'RAV', 'SKCN', 'Cravo Norte Airport', NULL, 'CO', 'Arauca', 6.3168400, -70.2107000, 'active', '2026-01-31 19:17:21', '2026-01-31 19:17:21'),
(2376, 'RVE', 'SKSA', 'Los Colonizadores Airport', NULL, 'CO', 'Arauca', 6.9518700, -71.8572000, 'active', '2026-01-31 19:17:22', '2026-01-31 19:17:22'),
(2377, 'TME', 'SKTM', 'Gabriel Vargas Santos Airport', NULL, 'CO', 'Arauca', 6.4510800, -71.7603000, 'active', '2026-01-31 19:17:22', '2026-01-31 19:17:22'),
(2378, 'BAQ', 'SKBQ', 'Ernesto Cortissoz International Airport', NULL, 'CO', 'Atlantico', 10.8896000, -74.7808000, 'active', '2026-01-31 19:17:22', '2026-01-31 19:17:22'),
(2379, 'CTG', 'SKCG', 'Rafael Nunez International Airport', NULL, 'CO', 'Bolivar', 10.4424000, -75.5130000, 'active', '2026-01-31 19:17:23', '2026-01-31 19:17:23'),
(2380, 'MGN', 'SKMG', 'Baracoa Regional Airport', NULL, 'CO', 'Bolivar', 9.2847400, -74.8461000, 'active', '2026-01-31 19:17:23', '2026-01-31 19:17:23'),
(2381, 'MMP', 'SKMP', 'San Bernardo Airport', NULL, 'CO', 'Bolivar', 9.7991100, -74.7860000, 'active', '2026-01-31 19:17:23', '2026-01-31 19:17:23'),
(2382, 'GCA', NULL, 'Guacamayas Airport', NULL, 'CO', 'Boyaca', 2.2833300, -74.9500000, 'active', '2026-01-31 19:17:24', '2026-01-31 19:17:24'),
(2383, 'MOY', NULL, 'Monterrey Airport', NULL, 'CO', 'Boyaca', 4.9069300, -72.8948000, 'active', '2026-01-31 19:17:24', '2026-01-31 19:17:24'),
(2384, 'PYA', 'SKVL', 'Velasquez Airport', NULL, 'CO', 'Boyaca', 5.9390400, -74.4570000, 'active', '2026-01-31 19:17:24', '2026-01-31 19:17:24'),
(2385, 'RON', 'SKPA', 'Juan Jose Rondon', NULL, 'CO', 'Boyaca', 6.2830000, -71.0830000, 'active', '2026-01-31 19:17:25', '2026-01-31 19:17:25'),
(2386, 'SJG', NULL, 'San Pedro de Jagua Airport', NULL, 'CO', 'Boyaca', 4.6500000, -73.3333000, 'active', '2026-01-31 19:17:25', '2026-01-31 19:17:25'),
(2387, 'SOX', 'SKSO', 'Alberto Lleras Camargo Airport', NULL, 'CO', 'Boyaca', 5.6773200, -72.9703000, 'active', '2026-01-31 19:17:25', '2026-01-31 19:17:25'),
(2388, 'TAU', 'SKTA', 'Tauramena Airport', NULL, 'CO', 'Boyaca', 5.0128100, -72.7424000, 'active', '2026-01-31 19:17:26', '2026-01-31 19:17:26'),
(2389, 'MZL', 'SKMZ', 'La Nubia Airport (Santaguida Airport)', NULL, 'CO', 'Caldas', 5.0296000, -75.4647000, 'active', '2026-01-31 19:17:26', '2026-01-31 19:17:26'),
(2390, 'ACR', 'SKAC', 'Araracuara Airport', NULL, 'CO', 'Caqueta', -0.5833000, -72.4083000, 'active', '2026-01-31 19:17:26', '2026-01-31 19:17:26'),
(2391, 'AYG', 'SKYA', 'Yaguara Airport', NULL, 'CO', 'Caqueta', 1.5441700, -73.9333000, 'active', '2026-01-31 19:17:27', '2026-01-31 19:17:27'),
(2392, 'CQT', NULL, 'Caquetania Airport', NULL, 'CO', 'Caqueta', 2.0333300, -74.2167000, 'active', '2026-01-31 19:17:27', '2026-01-31 19:17:27'),
(2393, 'CUI', NULL, 'Curillo Airport', NULL, 'CO', 'Caqueta', 4.6666700, -72.0000000, 'active', '2026-01-31 19:17:27', '2026-01-31 19:17:27'),
(2394, 'FLA', 'SKFL', 'Gustavo Artunduaga Paredes Airport', NULL, 'CO', 'Caqueta', 1.5891900, -75.5644000, 'active', '2026-01-31 19:17:28', '2026-01-31 19:17:28'),
(2395, 'SVI', 'SKSV', 'Eduardo Falla Solano Airport', NULL, 'CO', 'Caqueta', 2.1521700, -74.7663000, 'active', '2026-01-31 19:17:28', '2026-01-31 19:17:28'),
(2396, 'TQS', 'SKTQ', 'Captain Ernesto Esguerra Cubides Air Base', NULL, 'CO', 'Caqueta', 0.7459000, -75.2340000, 'active', '2026-01-31 19:17:28', '2026-01-31 19:17:28'),
(2397, 'EYP', 'SKYP', 'El Alcaravan Airport', NULL, 'CO', 'Casanare', 5.3191100, -72.3840000, 'active', '2026-01-31 19:17:29', '2026-01-31 19:17:29'),
(2398, 'HTZ', 'SKHC', 'Hato Corozal Airport', NULL, 'CO', 'Casanare', 6.1500000, -71.7500000, 'active', '2026-01-31 19:17:29', '2026-01-31 19:17:29'),
(2399, 'NUH', NULL, 'Nunchia Airport', NULL, 'CO', 'Casanare', 5.6500000, -72.2000000, 'active', '2026-01-31 19:17:29', '2026-01-31 19:17:29'),
(2400, 'ORC', 'SKOE', 'Orocue Airport', NULL, 'CO', 'Casanare', 4.7922200, -71.3564000, 'active', '2026-01-31 19:17:30', '2026-01-31 19:17:30'),
(2401, 'PRE', NULL, 'Pore Airport', NULL, 'CO', 'Casanare', 5.7333300, -71.9833000, 'active', '2026-01-31 19:17:30', '2026-01-31 19:17:30'),
(2402, 'PZA', 'SKPZ', 'Paz de Ariporo Airport', NULL, 'CO', 'Casanare', 5.8761500, -71.8866000, 'active', '2026-01-31 19:17:30', '2026-01-31 19:17:30'),
(2403, 'SQE', NULL, 'San Luis de Palenque Airport', NULL, 'CO', 'Casanare', 5.4138000, -71.7286000, 'active', '2026-01-31 19:17:31', '2026-01-31 19:17:31'),
(2404, 'TDA', 'SKTD', 'Trinidad Airport', NULL, 'CO', 'Casanare', 5.4327800, -71.6625000, 'active', '2026-01-31 19:17:31', '2026-01-31 19:17:31'),
(2405, 'TTM', NULL, 'Tablon de Tamara Airport', NULL, 'CO', 'Casanare', 5.7244800, -72.1030000, 'active', '2026-01-31 19:17:31', '2026-01-31 19:17:31'),
(2406, 'GPI', 'SKGP', 'Guapi Airport (Juan Casiano Airport)', NULL, 'CO', 'Cauca', 2.5701300, -77.8986000, 'active', '2026-01-31 19:17:32', '2026-01-31 19:17:32'),
(2407, 'LMX', NULL, 'Lopez de Micay Airport', NULL, 'CO', 'Cauca', 3.0500000, -77.5500000, 'active', '2026-01-31 19:17:32', '2026-01-31 19:17:32'),
(2408, 'PPN', 'SKPP', 'Guillermo Leon Valencia Airport', NULL, 'CO', 'Cauca', 2.4544000, -76.6093000, 'active', '2026-01-31 19:17:33', '2026-01-31 19:17:33'),
(2409, 'TBD', 'SKMB', 'Timbiqui Airport', NULL, 'CO', 'Cauca', 2.7670000, -77.6670000, 'active', '2026-01-31 19:17:33', '2026-01-31 19:17:33'),
(2410, 'DZI', NULL, 'Codazzi Airport', NULL, 'CO', 'Cesar', 10.0966000, -73.2337000, 'active', '2026-01-31 19:17:33', '2026-01-31 19:17:33'),
(2411, 'GRA', NULL, 'Gamarra Airport', NULL, 'CO', 'Cesar', 8.3419700, -73.7057000, 'active', '2026-01-31 19:17:34', '2026-01-31 19:17:34'),
(2412, 'HAY', 'SKAG', 'Hacaritama Airport', NULL, 'CO', 'Cesar', 8.2472200, -73.5819000, 'active', '2026-01-31 19:17:34', '2026-01-31 19:17:34'),
(2413, 'VUP', 'SKVP', 'Alfonso Lopez Pumarejo Airport', NULL, 'CO', 'Cesar', 10.4350000, -73.2495000, 'active', '2026-01-31 19:17:35', '2026-01-31 19:17:35'),
(2414, 'ACD', 'SKAD', 'Alcides Fernandez Airport', NULL, 'CO', 'Choco', 8.5166700, -77.3000000, 'active', '2026-01-31 19:17:35', '2026-01-31 19:17:35'),
(2415, 'BHF', 'SKCP', 'Bahia Cupica Airport', NULL, 'CO', 'Choco', 6.5500000, -77.3263000, 'active', '2026-01-31 19:17:36', '2026-01-31 19:17:36'),
(2416, 'BSC', 'SKBS', 'Jose Celestino Mutis Airport', NULL, 'CO', 'Choco', 6.2029200, -77.3947000, 'active', '2026-01-31 19:17:36', '2026-01-31 19:17:36'),
(2417, 'COG', 'SKCD', 'Mandinga Airport', NULL, 'CO', 'Choco', 5.0833300, -76.7000000, 'active', '2026-01-31 19:17:36', '2026-01-31 19:17:36'),
(2418, 'CPB', 'SKCA', 'Capurgana Airport', NULL, 'CO', 'Choco', 8.6333300, -77.3500000, 'active', '2026-01-31 19:17:37', '2026-01-31 19:17:37'),
(2419, 'GGL', NULL, 'Gilgal Airport', NULL, 'CO', 'Choco', 8.3333300, -77.0833000, 'active', '2026-01-31 19:17:37', '2026-01-31 19:17:37'),
(2420, 'JUO', 'SKJU', 'Jurado Airport', NULL, 'CO', 'Choco', 6.5166700, -76.6000000, 'active', '2026-01-31 19:17:37', '2026-01-31 19:17:37'),
(2421, 'NQU', 'SKNQ', 'Reyes Murillo Airport', NULL, 'CO', 'Choco', 5.6964000, -77.2806000, 'active', '2026-01-31 19:17:38', '2026-01-31 19:17:38'),
(2422, 'UIB', 'SKUI', 'El Carano Airport', NULL, 'CO', 'Choco', 5.6907600, -76.6412000, 'active', '2026-01-31 19:17:38', '2026-01-31 19:17:38'),
(2423, 'AYA', NULL, 'Ayapel Airport', NULL, 'CO', 'Cordoba', 8.3000000, -75.1500000, 'active', '2026-01-31 19:17:38', '2026-01-31 19:17:38'),
(2424, 'LRI', NULL, 'Lorica Airport', NULL, 'CO', 'Cordoba', 9.0333300, -75.7000000, 'active', '2026-01-31 19:17:39', '2026-01-31 19:17:39'),
(2425, 'MTB', 'SKML', 'Montelibano Airport', NULL, 'CO', 'Cordoba', 7.9717400, -75.4325000, 'active', '2026-01-31 19:17:39', '2026-01-31 19:17:39'),
(2426, 'MTR', 'SKMR', 'Los Garzones Airport', NULL, 'CO', 'Cordoba', 8.8237400, -75.8258000, 'active', '2026-01-31 19:17:39', '2026-01-31 19:17:39'),
(2427, 'PLC', NULL, 'Planeta Rica Airport', NULL, 'CO', 'Cordoba', 8.4000000, -75.6000000, 'active', '2026-01-31 19:17:40', '2026-01-31 19:17:40'),
(2428, 'SCA', NULL, 'Santa Catalina Airport', NULL, 'CO', 'Cordoba', 8.5000000, -76.1750000, 'active', '2026-01-31 19:17:40', '2026-01-31 19:17:40'),
(2429, 'EUO', NULL, 'Paratebueno Airport', NULL, 'CO', 'Cundinamarca', 4.3833300, -73.2000000, 'active', '2026-01-31 19:17:40', '2026-01-31 19:17:40'),
(2430, 'HRR', NULL, 'La Herrera Airport', NULL, 'CO', 'Cundinamarca', 3.2166700, -75.8500000, 'active', '2026-01-31 19:17:41', '2026-01-31 19:17:41'),
(2431, 'MND', NULL, 'Medina Airport', NULL, 'CO', 'Cundinamarca', 4.5166700, -73.2833000, 'active', '2026-01-31 19:17:41', '2026-01-31 19:17:41'),
(2432, 'PAL', 'SKPQ', 'Captain German Olano Moreno Air Base', NULL, 'CO', 'Cundinamarca', 5.4836100, -74.6574000, 'active', '2026-01-31 19:17:41', '2026-01-31 19:17:41'),
(2433, 'BOG', 'SKBO', 'El Dorado International Airport', NULL, 'CO', 'Distrito Capital de Bogota', 4.7015900, -74.1469000, 'active', '2026-01-31 19:17:42', '2026-01-31 19:17:42'),
(2434, 'MHF', NULL, 'Morichal Airport', NULL, 'CO', 'Guainia', 1.7500000, -69.9167000, 'active', '2026-01-31 19:17:42', '2026-01-31 19:17:42'),
(2435, 'NAD', NULL, 'Macanal Airport', NULL, 'CO', 'Guainia', 2.5666700, -67.5833000, 'active', '2026-01-31 19:17:42', '2026-01-31 19:17:42'),
(2436, 'NBB', 'SKBM', 'Barranco Minas Airport', NULL, 'CO', 'Guainia', 3.4833300, -69.8000000, 'active', '2026-01-31 19:17:44', '2026-01-31 19:17:44'),
(2437, 'PDA', 'SKPD', 'Obando Airport', NULL, 'CO', 'Guainia', 3.8535300, -67.9062000, 'active', '2026-01-31 19:17:44', '2026-01-31 19:17:44'),
(2438, 'AYI', NULL, 'Yari Airport', NULL, 'CO', 'Guaviare', -0.3833330, -72.2667000, 'active', '2026-01-31 19:17:45', '2026-01-31 19:17:45'),
(2439, 'MFS', 'SKMF', 'Miraflores Airport', NULL, 'CO', 'Guaviare', 1.3500000, -71.9444000, 'active', '2026-01-31 19:17:45', '2026-01-31 19:17:45'),
(2440, 'SJE', 'SKSJ', 'Jorge Enrique Gonzalez Torres Airport', NULL, 'CO', 'Guaviare', 2.5796900, -72.6394000, 'active', '2026-01-31 19:17:45', '2026-01-31 19:17:45'),
(2441, 'CJD', NULL, 'Candilejas Airport', NULL, 'CO', 'Huila', 2.0666700, -74.5833000, 'active', '2026-01-31 19:17:46', '2026-01-31 19:17:46'),
(2442, 'NVA', 'SKNV', 'Benito Salas Airport', NULL, 'CO', 'Huila', 2.9501500, -75.2940000, 'active', '2026-01-31 19:17:46', '2026-01-31 19:17:46'),
(2443, 'PCC', NULL, 'Puerto Rico Airport', NULL, 'CO', 'Huila', 1.9166700, -75.1667000, 'active', '2026-01-31 19:17:46', '2026-01-31 19:17:46'),
(2444, 'PTX', 'SKPI', 'Contador Airport', NULL, 'CO', 'Huila', 1.8577700, -76.0857000, 'active', '2026-01-31 19:17:47', '2026-01-31 19:17:47'),
(2445, 'SRO', NULL, 'Santana Ramos Airport', NULL, 'CO', 'Huila', 2.2166700, -75.2500000, 'active', '2026-01-31 19:17:47', '2026-01-31 19:17:47'),
(2446, 'MCJ', 'SKLM', 'Jorge Isaacs Airport (La Mina Airport)', NULL, 'CO', 'La Guajira', 11.2325000, -72.4901000, 'active', '2026-01-31 19:17:47', '2026-01-31 19:17:47'),
(2447, 'RCH', 'SKRH', 'Almirante Padilla Airport', NULL, 'CO', 'La Guajira', 11.5262000, -72.9260000, 'active', '2026-01-31 19:17:48', '2026-01-31 19:17:48'),
(2448, 'SJH', NULL, 'San Juan del Cesar Airport', NULL, 'CO', 'La Guajira', 10.7667000, -73.0167000, 'active', '2026-01-31 19:17:48', '2026-01-31 19:17:48'),
(2449, 'ELB', 'SKBC', 'Las Flores Airport', NULL, 'CO', 'Magdalena', 9.0455400, -73.9749000, 'active', '2026-01-31 19:17:48', '2026-01-31 19:17:48'),
(2450, 'IVO', NULL, 'Chibolo Airport', NULL, 'CO', 'Magdalena', 10.0167000, -74.6833000, 'active', '2026-01-31 19:17:49', '2026-01-31 19:17:49'),
(2451, 'PLT', 'SKPL', 'Plato Airport', NULL, 'CO', 'Magdalena', 9.8000000, -74.7833000, 'active', '2026-01-31 19:17:49', '2026-01-31 19:17:49'),
(2452, 'SMR', 'SKSM', 'Simon Bolivar International Airport', NULL, 'CO', 'Magdalena', 11.1196000, -74.2306000, 'active', '2026-01-31 19:17:49', '2026-01-31 19:17:49'),
(2453, 'API', 'SKAP', 'Captain Luis F. Gomez Nino Air Base', NULL, 'CO', 'Meta', 4.0760700, -73.5627000, 'active', '2026-01-31 19:17:50', '2026-01-31 19:17:50'),
(2454, 'BAC', NULL, 'Barranca de Upia Airport', NULL, 'CO', 'Meta', 4.5833300, -72.9667000, 'active', '2026-01-31 19:17:50', '2026-01-31 19:17:50'),
(2455, 'CCO', 'SKCI', 'Carimagua Airport', NULL, 'CO', 'Meta', 4.5641700, -71.3364000, 'active', '2026-01-31 19:17:50', '2026-01-31 19:17:50'),
(2456, 'ELJ', 'SVWX', 'El Recreo Airport', NULL, 'CO', 'Meta', 2.0000000, -74.1333000, 'active', '2026-01-31 19:17:51', '2026-01-31 19:17:51'),
(2457, 'GAA', NULL, 'Guamal Airport', NULL, 'CO', 'Meta', 9.0446500, -73.0973000, 'active', '2026-01-31 19:17:51', '2026-01-31 19:17:51'),
(2458, 'GMC', NULL, 'Guerima Airport', NULL, 'CO', 'Meta', 3.6291800, -70.3233000, 'active', '2026-01-31 19:17:51', '2026-01-31 19:17:51'),
(2459, 'LMC', 'SKNA', 'La Macarena Airport', NULL, 'CO', 'Meta', 2.1736000, -73.7862000, 'active', '2026-01-31 19:17:52', '2026-01-31 19:17:52'),
(2460, 'URI', 'SKUB', 'Uribe Airport', NULL, 'CO', 'Meta', 3.2166700, -74.4000000, 'active', '2026-01-31 19:17:52', '2026-01-31 19:17:52'),
(2461, 'VVC', 'SKVV', 'La Vanguardia Airport', NULL, 'CO', 'Meta', 4.1678700, -73.6138000, 'active', '2026-01-31 19:17:52', '2026-01-31 19:17:52'),
(2462, 'ECR', 'SKEH', 'El Charco Airport', NULL, 'CO', 'Narino', 2.4494400, -78.0942000, 'active', '2026-01-31 19:17:53', '2026-01-31 19:17:53'),
(2463, 'IPI', 'SKIP', 'San Luis Airport', NULL, 'CO', 'Narino', 0.8619250, -77.6718000, 'active', '2026-01-31 19:17:53', '2026-01-31 19:17:53'),
(2464, 'ISD', NULL, 'Iscuande Airport', NULL, 'CO', 'Narino', 2.4458300, -77.9818000, 'active', '2026-01-31 19:17:53', '2026-01-31 19:17:53'),
(2465, 'MQR', NULL, 'Mosquera Airport', NULL, 'CO', 'Narino', 2.6495500, -78.3361000, 'active', '2026-01-31 19:17:54', '2026-01-31 19:17:54'),
(2466, 'PSO', 'SKPS', 'Antonio Narino Airport', NULL, 'CO', 'Narino', 1.3962500, -77.2915000, 'active', '2026-01-31 19:17:54', '2026-01-31 19:17:54'),
(2467, 'PYN', NULL, 'Payan Airport', NULL, 'CO', 'Narino', 1.8000000, -78.1667000, 'active', '2026-01-31 19:17:54', '2026-01-31 19:17:54'),
(2468, 'TCO', 'SKCO', 'La Florida Airport', NULL, 'CO', 'Narino', 1.8144200, -78.7492000, 'active', '2026-01-31 19:17:55', '2026-01-31 19:17:55'),
(2469, 'CUC', 'SKCC', 'Camilo Daza International Airport', NULL, 'CO', 'Norte de Santander', 7.9275700, -72.5115000, 'active', '2026-01-31 19:17:55', '2026-01-31 19:17:55'),
(2470, 'OCV', 'SKOC', 'Aguas Claras Airport', NULL, 'CO', 'Norte de Santander', 8.3150600, -73.3583000, 'active', '2026-01-31 19:17:55', '2026-01-31 19:17:55'),
(2471, 'TIB', 'SKTB', 'Tibu Airport', NULL, 'CO', 'Norte de Santander', 8.6315200, -72.7304000, 'active', '2026-01-31 19:17:56', '2026-01-31 19:17:56'),
(2472, 'LQM', 'SKLG', 'Caucaya Airport', NULL, 'CO', 'Putumayo', -0.1822780, -74.7708000, 'active', '2026-01-31 19:17:56', '2026-01-31 19:17:56'),
(2473, 'PUU', 'SKAS', 'Tres de Mayo Airport', NULL, 'CO', 'Putumayo', 0.5052280, -76.5008000, 'active', '2026-01-31 19:17:56', '2026-01-31 19:17:56'),
(2474, 'VGZ', 'SKVG', 'Villa Garzon Airport', NULL, 'CO', 'Putumayo', 0.9787670, -76.6056000, 'active', '2026-01-31 19:17:57', '2026-01-31 19:17:57'),
(2475, 'AXM', 'SKAR', 'El Eden International Airport', NULL, 'CO', 'Quindio', 4.4527800, -75.7664000, 'active', '2026-01-31 19:17:57', '2026-01-31 19:17:57'),
(2476, 'PEI', 'SKPE', 'Matecana International Airport', NULL, 'CO', 'Risaralda', 4.8126700, -75.7395000, 'active', '2026-01-31 19:17:57', '2026-01-31 19:17:57'),
(2477, 'ADZ', 'SKSP', 'Gustavo Rojas Pinilla International Airport', NULL, 'CO', 'San Andres, Providencia y Santa Catalina', 12.5836000, -81.7112000, 'active', '2026-01-31 19:17:58', '2026-01-31 19:17:58'),
(2478, 'PVA', 'SKPV', 'El Embrujo Airport', NULL, 'CO', 'San Andres, Providencia y Santa Catalina', 13.3569000, -81.3583000, 'active', '2026-01-31 19:17:58', '2026-01-31 19:17:58'),
(2479, 'AZT', NULL, 'Zapatoca Airport', NULL, 'CO', 'Santander', 6.8166700, -73.2833000, 'active', '2026-01-31 19:17:58', '2026-01-31 19:17:58'),
(2480, 'BGA', 'SKBG', 'Palonegro International Airport', NULL, 'CO', 'Santander', 7.1265000, -73.1848000, 'active', '2026-01-31 19:17:59', '2026-01-31 19:17:59'),
(2481, 'CIM', 'SKCM', 'Cimitarra Airport', NULL, 'CO', 'Santander', 6.3670000, -73.9670000, 'active', '2026-01-31 19:17:59', '2026-01-31 19:17:59'),
(2482, 'EJA', 'SKEJ', 'Yariguies Airport', NULL, 'CO', 'Santander', 7.0243300, -73.8068000, 'active', '2026-01-31 19:18:00', '2026-01-31 19:18:00'),
(2483, 'SNT', 'SKRU', 'Las Cruces Airport', NULL, 'CO', 'Santander', 7.3832200, -73.5054000, 'active', '2026-01-31 19:18:00', '2026-01-31 19:18:00'),
(2484, 'CVE', 'SKCV', 'Covenas Airport', NULL, 'CO', 'Sucre', 9.4009200, -75.6913000, 'active', '2026-01-31 19:18:00', '2026-01-31 19:18:00'),
(2485, 'CZU', 'SKCZ', 'Las Brujas Airport', NULL, 'CO', 'Sucre', 9.3327400, -75.2856000, 'active', '2026-01-31 19:18:01', '2026-01-31 19:18:01'),
(2486, 'SRS', NULL, 'San Marcos Airport', NULL, 'CO', 'Sucre', 8.6900000, -75.1560000, 'active', '2026-01-31 19:18:01', '2026-01-31 19:18:01'),
(2487, 'TLU', 'SKTL', 'Golfo de Morrosquillo Airport', NULL, 'CO', 'Sucre', 9.5094500, -75.5854000, 'active', '2026-01-31 19:18:01', '2026-01-31 19:18:01'),
(2488, 'CPL', 'SKHA', 'General Navas Pardo Airport', NULL, 'CO', 'Tolima', 3.7170000, -75.4670000, 'active', '2026-01-31 19:18:02', '2026-01-31 19:18:02'),
(2489, 'GIR', 'SKGI', 'Santiago Vila Airport', NULL, 'CO', 'Tolima', 4.2762400, -74.7967000, 'active', '2026-01-31 19:18:02', '2026-01-31 19:18:02'),
(2490, 'IBE', 'SKIB', 'Perales Airport', NULL, 'CO', 'Tolima', 4.4216100, -75.1333000, 'active', '2026-01-31 19:18:02', '2026-01-31 19:18:02'),
(2491, 'MQU', 'SKQU', 'Mariquita Airport', NULL, 'CO', 'Tolima', 5.2125600, -74.8836000, 'active', '2026-01-31 19:18:03', '2026-01-31 19:18:03'),
(2492, 'PLA', NULL, 'Planadas Airport', NULL, 'CO', 'Tolima', 3.3000000, -75.7000000, 'active', '2026-01-31 19:18:03', '2026-01-31 19:18:03'),
(2493, 'ACL', NULL, 'Aguaclara Airport', NULL, 'CO', 'Valle del Cauca', 4.7536100, -73.0028000, 'active', '2026-01-31 19:18:03', '2026-01-31 19:18:03'),
(2494, 'BUN', 'SKBU', 'Gerardo Tobar Lopez Airport', NULL, 'CO', 'Valle del Cauca', 3.8196300, -76.9898000, 'active', '2026-01-31 19:18:04', '2026-01-31 19:18:04'),
(2495, 'CLO', 'SKCL', 'Alfonso Bonilla Aragon International Airport', NULL, 'CO', 'Valle del Cauca', 3.5432200, -76.3816000, 'active', '2026-01-31 19:18:04', '2026-01-31 19:18:04'),
(2496, 'CRC', 'SKGO', 'Santa Ana Airport', NULL, 'CO', 'Valle del Cauca', 4.7581800, -75.9557000, 'active', '2026-01-31 19:18:04', '2026-01-31 19:18:04'),
(2497, 'ULQ', 'SKUL', 'Heriberto Gil Martinez', NULL, 'CO', 'Valle del Cauca', 4.0883600, -76.2351000, 'active', '2026-01-31 19:18:05', '2026-01-31 19:18:05'),
(2498, 'ARF', NULL, 'Acaricuara Airport', NULL, 'CO', 'Vaupes', 0.5333330, -70.1333000, 'active', '2026-01-31 19:18:05', '2026-01-31 19:18:05'),
(2499, 'CUO', 'SKCR', 'Caruru Airport', NULL, 'CO', 'Vaupes', 1.0136000, -71.2961000, 'active', '2026-01-31 19:18:05', '2026-01-31 19:18:05'),
(2500, 'MFB', NULL, 'Monfort Airport', NULL, 'CO', 'Vaupes', 0.6333330, -69.7500000, 'active', '2026-01-31 19:18:06', '2026-01-31 19:18:06'),
(2501, 'MIX', NULL, 'Miriti-Parana Airport', NULL, 'CO', 'Vaupes', -1.1333300, -70.2500000, 'active', '2026-01-31 19:18:06', '2026-01-31 19:18:06'),
(2502, 'MVP', 'SKMU', 'Fabio Alberto Leon Bentley Airport', NULL, 'CO', 'Vaupes', 1.2536600, -70.2339000, 'active', '2026-01-31 19:18:06', '2026-01-31 19:18:06'),
(2503, 'VAB', NULL, 'Yavarate Airport', NULL, 'CO', 'Vaupes', 1.1166700, -70.7500000, 'active', '2026-01-31 19:18:07', '2026-01-31 19:18:07'),
(2504, 'CSR', NULL, 'Casuarito Airport', NULL, 'CO', 'Vichada', 5.8333300, -68.1333000, 'active', '2026-01-31 19:18:07', '2026-01-31 19:18:07'),
(2505, 'LGT', 'SKGA', 'Las Gaviotas Airport', NULL, 'CO', 'Vichada', 4.5497200, -70.9250000, 'active', '2026-01-31 19:18:07', '2026-01-31 19:18:07'),
(2506, 'LPE', 'SKIM', 'La Primavera Airport', NULL, 'CO', 'Vichada', 3.7333300, -76.2167000, 'active', '2026-01-31 19:18:08', '2026-01-31 19:18:08'),
(2507, 'PCR', 'SKPC', 'German Olano Airport', NULL, 'CO', 'Vichada', 6.1847200, -67.4932000, 'active', '2026-01-31 19:18:08', '2026-01-31 19:18:08'),
(2508, 'SSL', 'SKSL', 'Santa Rosalia Airport', NULL, 'CO', 'Vichada', 5.1309000, -70.8682000, 'active', '2026-01-31 19:18:08', '2026-01-31 19:18:08'),
(2509, 'FON', 'MRAN', 'La Fortuna Airport', NULL, 'CR', 'Alajuela', 10.4780000, -84.6345000, 'active', '2026-01-31 19:18:09', '2026-01-31 19:18:09'),
(2510, 'LSL', 'MRLC', 'Los Chiles Airport', NULL, 'CR', 'Alajuela', 11.0353000, -84.7061000, 'active', '2026-01-31 19:18:09', '2026-01-31 19:18:09'),
(2511, 'RFR', 'MRRF', 'Rio Frio Airport', NULL, 'CR', 'Alajuela', 10.3274000, -83.8876000, 'active', '2026-01-31 19:18:09', '2026-01-31 19:18:09'),
(2512, 'SJO', 'MROC', 'Juan Santamaria International Airport', NULL, 'CR', 'Alajuela', 9.9938600, -84.2088000, 'active', '2026-01-31 19:18:10', '2026-01-31 19:18:10'),
(2513, 'UPL', 'MRUP', 'Upala Airport', NULL, 'CR', 'Alajuela', 10.8922000, -85.0162000, 'active', '2026-01-31 19:18:10', '2026-01-31 19:18:10'),
(2514, 'CSC', 'MRMJ', 'Canas Mojica Airport', NULL, 'CR', 'Guanacaste', 10.4307000, -85.1746000, 'active', '2026-01-31 19:18:10', '2026-01-31 19:18:10'),
(2515, 'LIR', 'MRLB', 'Daniel Oduber Quiros International Airport', NULL, 'CR', 'Guanacaste', 10.5933000, -85.5444000, 'active', '2026-01-31 19:18:11', '2026-01-31 19:18:11'),
(2516, 'NCT', 'MRNC', 'Nicoya Guanacaste Airport', NULL, 'CR', 'Guanacaste', 10.1394000, -85.4458000, 'active', '2026-01-31 19:18:11', '2026-01-31 19:18:11'),
(2517, 'NOB', 'MRNS', 'Nosara Airport', NULL, 'CR', 'Guanacaste', 9.9764900, -85.6530000, 'active', '2026-01-31 19:18:12', '2026-01-31 19:18:12'),
(2518, 'PBP', 'MRIA', 'Punta Islita Airport', NULL, 'CR', 'Guanacaste', 9.8561100, -85.3708000, 'active', '2026-01-31 19:18:12', '2026-01-31 19:18:12'),
(2519, 'PLD', 'MRCR', 'Carrillo Airport (Playa Samara/Carrillo Airport)', NULL, 'CR', 'Guanacaste', 9.8705100, -85.4814000, 'active', '2026-01-31 19:18:12', '2026-01-31 19:18:12'),
(2520, 'TNO', 'MRTM', 'Tamarindo Airport', NULL, 'CR', 'Guanacaste', 10.3135000, -85.8155000, 'active', '2026-01-31 19:18:13', '2026-01-31 19:18:13'),
(2521, 'BCL', 'MRBC', 'Barra del Colorado Airport', NULL, 'CR', 'Limon', 10.7687000, -83.5856000, 'active', '2026-01-31 19:18:13', '2026-01-31 19:18:13'),
(2522, 'GPL', 'MRGP', 'Guapiles Airport', NULL, 'CR', 'Limon', 10.2172000, -83.7970000, 'active', '2026-01-31 19:18:13', '2026-01-31 19:18:13'),
(2523, 'LIO', 'MRLM', 'Limon International Airport', NULL, 'CR', 'Limon', 9.9579600, -83.0220000, 'active', '2026-01-31 19:18:14', '2026-01-31 19:18:14'),
(2524, 'TTQ', 'MRBT', 'Tortuguero Airport (Barra de Tortuguero Airport)', NULL, 'CR', 'Limon', 10.4200000, -83.6095000, 'active', '2026-01-31 19:18:14', '2026-01-31 19:18:14'),
(2525, 'ACO', NULL, 'Cobano Airport', NULL, 'CR', 'Puntarenas', 9.6921000, -85.0966000, 'active', '2026-01-31 19:18:14', '2026-01-31 19:18:14'),
(2526, 'BAI', 'MRBA', 'Buenos Aires Airport', NULL, 'CR', 'Puntarenas', 9.1639500, -83.3302000, 'active', '2026-01-31 19:18:15', '2026-01-31 19:18:15'),
(2527, 'DRK', 'MRDK', 'Drake Bay Airport', NULL, 'CR', 'Puntarenas', 8.7188900, -83.6417000, 'active', '2026-01-31 19:18:15', '2026-01-31 19:18:15'),
(2528, 'GLF', 'MRGF', 'Golfito Airport', NULL, 'CR', 'Puntarenas', 8.6540100, -83.1822000, 'active', '2026-01-31 19:18:15', '2026-01-31 19:18:15'),
(2529, 'JAP', 'MRCH', 'Chacarita Airport', NULL, 'CR', 'Puntarenas', 9.9814100, -84.7727000, 'active', '2026-01-31 19:18:16', '2026-01-31 19:18:16'),
(2530, 'OTR', 'MRCC', 'Coto 47 Airport', NULL, 'CR', 'Puntarenas', 8.6015600, -82.9686000, 'active', '2026-01-31 19:18:16', '2026-01-31 19:18:16'),
(2531, 'PJM', 'MRPJ', 'Puerto Jimenez Airport', NULL, 'CR', 'Puntarenas', 8.5333300, -83.3000000, 'active', '2026-01-31 19:18:16', '2026-01-31 19:18:16'),
(2532, 'PMZ', 'MRPM', 'Palmar Sur Airport', NULL, 'CR', 'Puntarenas', 8.9510300, -83.4686000, 'active', '2026-01-31 19:18:17', '2026-01-31 19:18:17'),
(2533, 'TMU', 'MRTR', 'Tambor Airport', NULL, 'CR', 'Puntarenas', 9.7385200, -85.0138000, 'active', '2026-01-31 19:18:17', '2026-01-31 19:18:17'),
(2534, 'TOO', 'MRSV', 'San Vito de Java Airport', NULL, 'CR', 'Puntarenas', 8.8261100, -82.9589000, 'active', '2026-01-31 19:18:18', '2026-01-31 19:18:18'),
(2535, 'XQP', 'MRQP', 'Quepos La Managua Airport', NULL, 'CR', 'Puntarenas', 9.4431600, -84.1298000, 'active', '2026-01-31 19:18:18', '2026-01-31 19:18:18'),
(2536, 'IPZ', 'MRSI', 'San Isidro de El General Airport', NULL, 'CR', 'San Jose', 9.3486100, -83.7125000, 'active', '2026-01-31 19:18:18', '2026-01-31 19:18:18'),
(2537, 'SYQ', 'MRPV', 'Tobias Bolanos International Airport', NULL, 'CR', 'San Jose', 9.9570500, -84.1398000, 'active', '2026-01-31 19:18:19', '2026-01-31 19:18:19'),
(2538, 'UPB', 'MUPB', 'Playa Baracoa Airport', NULL, 'CU', 'Artemisa', 23.0328000, -82.5794000, 'active', '2026-01-31 19:18:19', '2026-01-31 19:18:19'),
(2539, 'CMW', 'MUCM', 'Ignacio Agramonte International Airport', NULL, 'CU', 'Camaguey', 21.4203000, -77.8475000, 'active', '2026-01-31 19:18:19', '2026-01-31 19:18:19'),
(2540, 'AVI', 'MUCA', 'Maximo Gomez  Airport', NULL, 'CU', 'Ciego de Avila', 22.0271000, -78.7896000, 'active', '2026-01-31 19:18:20', '2026-01-31 19:18:20'),
(2541, 'CCC', 'MUCC', 'Jardines del Rey Airport', NULL, 'CU', 'Ciego de Avila', 22.4610000, -78.3284000, 'active', '2026-01-31 19:18:20', '2026-01-31 19:18:20'),
(2542, 'CFG', 'MUCF', 'Jaime Gonzalez Airport', NULL, 'CU', 'Cienfuegos', 22.1500000, -80.4142000, 'active', '2026-01-31 19:18:20', '2026-01-31 19:18:20'),
(2543, 'BYM', 'MUBY', 'Carlos Manuel de Cespedes Airport', NULL, 'CU', 'Granma', 20.3964000, -76.6214000, 'active', '2026-01-31 19:18:21', '2026-01-31 19:18:21'),
(2544, 'MZO', 'MUMZ', 'Sierra Maestra Airport', NULL, 'CU', 'Granma', 20.2881000, -77.0892000, 'active', '2026-01-31 19:18:21', '2026-01-31 19:18:21'),
(2545, 'BCA', 'MUBA', 'Gustavo Rizo Airport', NULL, 'CU', 'Guantanamo', 20.3653000, -74.5062000, 'active', '2026-01-31 19:18:21', '2026-01-31 19:18:21'),
(2546, 'GAO', 'MUGT', 'Mariana Grajales Airport', NULL, 'CU', 'Guantanamo', 20.0853000, -75.1583000, 'active', '2026-01-31 19:18:22', '2026-01-31 19:18:22'),
(2547, 'NBW', 'MUGM', 'Guantanamo Bay Naval Base', NULL, 'CU', 'Guantanamo', 19.9065000, -75.2071000, 'active', '2026-01-31 19:18:22', '2026-01-31 19:18:22'),
(2548, 'UMA', NULL, 'Punta de Maisi Airport', NULL, 'CU', 'Guantanamo', 20.2506000, -74.1505000, 'active', '2026-01-31 19:18:22', '2026-01-31 19:18:22'),
(2549, 'HOG', 'MUHG', 'Frank Pais Airport', NULL, 'CU', 'Holguin', 20.7856000, -76.3151000, 'active', '2026-01-31 19:18:23', '2026-01-31 19:18:23'),
(2550, 'MOA', 'MUMO', 'Orestes Acosta Airport', NULL, 'CU', 'Holguin', 20.6539000, -74.9222000, 'active', '2026-01-31 19:18:23', '2026-01-31 19:18:23'),
(2551, 'CYO', 'MUCL', 'Vilo Acuna Airport', NULL, 'CU', 'Isla de la Juventud', 21.6165000, -81.5460000, 'active', '2026-01-31 19:18:23', '2026-01-31 19:18:23'),
(2552, 'GER', 'MUNG', 'Rafael Cabrera Mustelier Airport', NULL, 'CU', 'Isla de la Juventud', 21.8347000, -82.7838000, 'active', '2026-01-31 19:18:24', '2026-01-31 19:18:24'),
(2553, 'SZJ', 'MUSN', 'Siguanea Airport', NULL, 'CU', 'Isla de la Juventud', 21.6425000, -82.9551000, 'active', '2026-01-31 19:18:24', '2026-01-31 19:18:24'),
(2554, 'HAV', 'MUHA', 'Jose Marti International Airport', NULL, 'CU', 'La Habana', 22.9892000, -82.4091000, 'active', '2026-01-31 19:18:24', '2026-01-31 19:18:24'),
(2555, 'VTU', 'MUVT', 'Hermanos Ameijeiras Airport', NULL, 'CU', 'Las Tunas', 20.9876000, -76.9358000, 'active', '2026-01-31 19:18:25', '2026-01-31 19:18:25'),
(2556, 'VRA', 'MUVR', 'Juan Gualberto Gomez Airport', NULL, 'CU', 'Matanzas', 23.0344000, -81.4353000, 'active', '2026-01-31 19:18:25', '2026-01-31 19:18:25'),
(2557, 'VRO', 'MUKW', 'Kawama Airport', NULL, 'CU', 'Matanzas', 23.1240000, -81.3016000, 'active', '2026-01-31 19:18:25', '2026-01-31 19:18:25'),
(2558, 'LCL', 'MULM', 'La Coloma Airport', NULL, 'CU', 'Pinar del Rio', 22.3361000, -83.6419000, 'active', '2026-01-31 19:18:26', '2026-01-31 19:18:26'),
(2559, 'SNJ', 'MUSJ', 'San Julian Air Base', NULL, 'CU', 'Pinar del Rio', 22.0953000, -84.1520000, 'active', '2026-01-31 19:18:26', '2026-01-31 19:18:26'),
(2560, 'TND', 'MUTD', 'Alberto Delgado Airport', NULL, 'CU', 'Sancti Spiritus', 21.7883000, -79.9972000, 'active', '2026-01-31 19:18:26', '2026-01-31 19:18:26'),
(2561, 'USS', 'MUSS', 'Sancti Spiritus Airport', NULL, 'CU', 'Sancti Spiritus', 21.9704000, -79.4427000, 'active', '2026-01-31 19:18:27', '2026-01-31 19:18:27'),
(2562, 'SCU', 'MUCU', 'Antonio Maceo International Airport', NULL, 'CU', 'Santiago de Cuba', 19.9698000, -75.8354000, 'active', '2026-01-31 19:18:27', '2026-01-31 19:18:27'),
(2563, 'BWW', 'MUBR', 'Las Brujas Airport', NULL, 'CU', 'Villa Clara', 22.6213000, -79.1472000, 'active', '2026-01-31 19:18:27', '2026-01-31 19:18:27'),
(2564, 'SNU', 'MUSC', 'Abel Santamaria Airport', NULL, 'CU', 'Villa Clara', 22.4922000, -79.9436000, 'active', '2026-01-31 19:18:28', '2026-01-31 19:18:28'),
(2565, 'BVC', 'GVBA', 'Aristides Pereira International Airport (Rabil Airport)', NULL, 'CV', 'Boa Vista', 16.1365000, -22.8889000, 'active', '2026-01-31 19:18:28', '2026-01-31 19:18:28'),
(2566, 'BVR', 'GVBR', 'Esperadinha Airport', NULL, 'CV', 'Brava', 14.8643000, -24.7460000, 'active', '2026-01-31 19:18:28', '2026-01-31 19:18:28'),
(2567, 'MMO', 'GVMA', 'Maio Airport', NULL, 'CV', 'Maio', 15.1559000, -23.2137000, 'active', '2026-01-31 19:18:29', '2026-01-31 19:18:29'),
(2568, 'RAI', 'GVNP', 'Nelson Mandela International Airport', NULL, 'CV', 'Ribeira Grande de Santiago', 14.9245000, -23.4935000, 'active', '2026-01-31 19:18:29', '2026-01-31 19:18:29'),
(2569, 'NTO', 'GVAN', 'Agostinho Neto Airport', NULL, 'CV', 'Ribeira Grande', 17.2028000, -25.0906000, 'active', '2026-01-31 19:18:29', '2026-01-31 19:18:29'),
(2570, 'SNE', 'GVSN', 'Preguica Airport', NULL, 'CV', 'Ribeira Grande', 16.5884000, -24.2847000, 'active', '2026-01-31 19:18:30', '2026-01-31 19:18:30'),
(2571, 'SID', 'GVAC', 'Amilcar Cabral International Airport', NULL, 'CV', 'Sal', 16.7414000, -22.9494000, 'active', '2026-01-31 19:18:30', '2026-01-31 19:18:30'),
(2572, 'MTI', 'GVMT', 'Mosteiros Airport', NULL, 'CV', 'Sao Filipe', 15.0450000, -24.3392000, 'active', '2026-01-31 19:18:30', '2026-01-31 19:18:30'),
(2573, 'SFL', 'GVSF', 'Sao Filipe Airport', NULL, 'CV', 'Sao Filipe', 14.8850000, -24.4800000, 'active', '2026-01-31 19:18:31', '2026-01-31 19:18:31'),
(2574, 'VXE', 'GVSV', 'Cesaria Evora Airport', NULL, 'CV', 'Sao Vicente', 16.8332000, -25.0553000, 'active', '2026-01-31 19:18:31', '2026-01-31 19:18:31'),
(2575, 'CUR', 'TNCC', 'Curacao International Airport (Hato Int\'l Airport)', NULL, 'CW', 'Curacao', 12.1889000, -68.9598000, 'active', '2026-01-31 19:18:31', '2026-01-31 19:18:31'),
(2576, 'XCH', 'YPXM', 'Christmas Island Airport', NULL, 'CX', 'Christmas Island', -10.4506000, 105.6900000, 'active', '2026-01-31 19:18:32', '2026-01-31 19:18:32'),
(2577, 'GEC', 'LCGK', 'Gecitkale Air Base', NULL, 'CY', 'Ammochostos', 35.2359000, 33.7244000, 'active', '2026-01-31 19:18:32', '2026-01-31 19:18:32'),
(2578, 'LCA', 'LCLK', 'Larnaca International Airport', NULL, 'CY', 'Larnaka', 34.8751000, 33.6249000, 'active', '2026-01-31 19:18:32', '2026-01-31 19:18:32'),
(2579, 'ECN', 'LCEN', 'Ercan International Airport', NULL, 'CY', 'Lefkosia', 35.1547000, 33.4961000, 'active', '2026-01-31 19:18:33', '2026-01-31 19:18:33'),
(2580, 'AKT', 'LCRA', 'RAF Akrotiri', NULL, 'CY', 'Lemesos', 34.5904000, 32.9879000, 'active', '2026-01-31 19:18:33', '2026-01-31 19:18:33'),
(2581, 'PFO', 'LCPH', 'Paphos International Airport', NULL, 'CY', 'Pafos', 34.7180000, 32.4857000, 'active', '2026-01-31 19:18:33', '2026-01-31 19:18:33'),
(2582, 'JCL', 'LKCS', 'Ceske Budejovice Airport (Plana Airport)', NULL, 'CZ', 'Jihocesky kraj', 48.9464000, 14.4275000, 'active', '2026-01-31 19:18:34', '2026-01-31 19:18:34'),
(2583, 'BRQ', 'LKTB', 'Brno-Turany Airport', NULL, 'CZ', 'Jihomoravsky kraj', 49.1513000, 16.6944000, 'active', '2026-01-31 19:18:34', '2026-01-31 19:18:34'),
(2584, 'KLV', 'LKKV', 'Karlovy Vary Airport', NULL, 'CZ', 'Karlovarsky kraj', 50.2030000, 12.9150000, 'active', '2026-01-31 19:18:34', '2026-01-31 19:18:34'),
(2585, 'MKA', 'LKMR', 'Marianske Lazne Airport', NULL, 'CZ', 'Karlovarsky kraj', 49.9228000, 12.7247000, 'active', '2026-01-31 19:18:35', '2026-01-31 19:18:35'),
(2586, 'OSR', 'LKMT', 'Leos Janacek Airport', NULL, 'CZ', 'Moravskoslezsky kraj', 49.6963000, 18.1111000, 'active', '2026-01-31 19:18:35', '2026-01-31 19:18:35');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(2587, 'ZBE', 'LKZA', 'Zabreh Airport', NULL, 'CZ', 'Moravskoslezsky kraj', 49.9283000, 18.0783000, 'active', '2026-01-31 19:18:35', '2026-01-31 19:18:35'),
(2588, 'OLO', 'LKOL', 'Olomouc Airport (Neredin Airport)', NULL, 'CZ', 'Olomoucky kraj', 49.5878000, 17.2108000, 'active', '2026-01-31 19:18:36', '2026-01-31 19:18:36'),
(2589, 'PRV', 'LKPO', 'Prerov Airport', NULL, 'CZ', 'Olomoucky kraj', 49.4258000, 17.4047000, 'active', '2026-01-31 19:18:36', '2026-01-31 19:18:36'),
(2590, 'PED', 'LKPD', 'Pardubice Airport', NULL, 'CZ', 'Pardubicky kraj', 50.0134000, 15.7386000, 'active', '2026-01-31 19:18:36', '2026-01-31 19:18:36'),
(2591, 'PRG', 'LKPR', 'Vaclav Havel Airport Prague', NULL, 'CZ', 'Stredocesky kraj', 50.1008000, 14.2600000, 'active', '2026-01-31 19:18:37', '2026-01-31 19:18:37'),
(2592, 'VOD', 'LKVO', 'Vodochody Airport', NULL, 'CZ', 'Stredocesky kraj', 50.2166000, 14.3958000, 'active', '2026-01-31 19:18:37', '2026-01-31 19:18:37'),
(2593, 'GTW', 'LKHO', 'Holesov Airport', NULL, 'CZ', 'Zlinsky kraj', 49.3144000, 17.5689000, 'active', '2026-01-31 19:18:38', '2026-01-31 19:18:38'),
(2594, 'UHE', 'LKKU', 'Kunovice Airport', NULL, 'CZ', 'Zlinsky kraj', 49.0294000, 17.4397000, 'active', '2026-01-31 19:18:38', '2026-01-31 19:18:38'),
(2595, 'FDH', 'EDNY', 'Friedrichshafen Airport (Bodensee Airport)', NULL, 'DE', 'Baden-Wurttemberg', 47.6713000, 9.5114900, 'active', '2026-01-31 19:18:38', '2026-01-31 19:18:38'),
(2596, 'FKB', 'EDSB', 'Karlsruhe/Baden-Baden Airport', NULL, 'DE', 'Baden-Wurttemberg', 48.7794000, 8.0805000, 'active', '2026-01-31 19:18:39', '2026-01-31 19:18:39'),
(2597, 'HDB', 'ETIE', 'Heidelberg Airport', NULL, 'DE', 'Baden-Wurttemberg', 49.3924000, 8.6519300, 'active', '2026-01-31 19:18:39', '2026-01-31 19:18:39'),
(2598, 'LHA', 'EDTL', 'Flughafen Lahr (Lahr Airport)', NULL, 'DE', 'Baden-Wurttemberg', 48.3693000, 7.8277200, 'active', '2026-01-31 19:18:39', '2026-01-31 19:18:39'),
(2599, 'MHG', 'EDFM', 'Mannheim City Airport', NULL, 'DE', 'Baden-Wurttemberg', 49.4731000, 8.5141700, 'active', '2026-01-31 19:18:40', '2026-01-31 19:18:40'),
(2600, 'STR', 'EDDS', 'Stuttgart Airport', NULL, 'DE', 'Baden-Wurttemberg', 48.6899000, 9.2219600, 'active', '2026-01-31 19:18:40', '2026-01-31 19:18:40'),
(2601, 'AGB', 'EDMA', 'Augsburg Airport', NULL, 'DE', 'Bayern', 48.4253000, 10.9317000, 'active', '2026-01-31 19:18:40', '2026-01-31 19:18:40'),
(2602, 'BYU', 'EDQD', 'Bindlacher Berg Airport', NULL, 'DE', 'Bayern', 49.9850000, 11.6400000, 'active', '2026-01-31 19:18:41', '2026-01-31 19:18:41'),
(2603, 'FEL', 'ETSF', 'Furstenfeldbruck Air Base', NULL, 'DE', 'Bayern', 48.2056000, 11.2669000, 'active', '2026-01-31 19:18:41', '2026-01-31 19:18:41'),
(2604, 'FMM', 'EDJA', 'Memmingen Airport', NULL, 'DE', 'Bayern', 47.9888000, 10.2395000, 'active', '2026-01-31 19:18:41', '2026-01-31 19:18:41'),
(2605, 'GHF', 'EDQG', 'Giebelstadt Airport', NULL, 'DE', 'Bayern', 49.6481000, 9.9663900, 'active', '2026-01-31 19:18:42', '2026-01-31 19:18:42'),
(2606, 'HOQ', 'EDQM', 'Hof-Plauen Airport', NULL, 'DE', 'Bayern', 50.2886000, 11.8564000, 'active', '2026-01-31 19:18:42', '2026-01-31 19:18:42'),
(2607, 'IGS', 'ETSI', 'Ingolstadt Manching Airport', NULL, 'DE', 'Bayern', 48.7157000, 11.5340000, 'active', '2026-01-31 19:18:42', '2026-01-31 19:18:42'),
(2608, 'ILH', 'ETIK', 'Illesheim Army Airfield', NULL, 'DE', 'Bayern', 49.4739000, 10.3881000, 'active', '2026-01-31 19:18:43', '2026-01-31 19:18:43'),
(2609, 'KZG', 'ETIN', 'Kitzingen Airport', NULL, 'DE', 'Bayern', 49.7431000, 10.2006000, 'active', '2026-01-31 19:18:43', '2026-01-31 19:18:43'),
(2610, 'MUC', 'EDDM', 'Munich Airport', NULL, 'DE', 'Bayern', 48.3538000, 11.7861000, 'active', '2026-01-31 19:18:43', '2026-01-31 19:18:43'),
(2611, 'NUE', 'EDDN', 'Nuremberg Airport', NULL, 'DE', 'Bayern', 49.4987000, 11.0781000, 'active', '2026-01-31 19:18:44', '2026-01-31 19:18:44'),
(2612, 'OBF', 'EDMO', 'Oberpfaffenhofen Airport', NULL, 'DE', 'Bayern', 48.0814000, 11.2831000, 'active', '2026-01-31 19:18:44', '2026-01-31 19:18:44'),
(2613, 'RBM', 'EDMS', 'Straubing Wallmuhle Airport', NULL, 'DE', 'Bayern', 48.9008000, 12.5167000, 'active', '2026-01-31 19:18:44', '2026-01-31 19:18:44'),
(2614, 'URD', 'EDQE', 'Burg Feuerstein Airport', NULL, 'DE', 'Bayern', 49.7942000, 11.1336000, 'active', '2026-01-31 19:18:45', '2026-01-31 19:18:45'),
(2615, 'TXL', 'EDDT', 'Berlin Tegel Airport', NULL, 'DE', 'Berlin', 52.5597000, 13.2877000, 'active', '2026-01-31 19:18:45', '2026-01-31 19:18:45'),
(2616, 'BER', 'EDDB', 'Berlin Brandenburg Airport', NULL, 'DE', 'Brandenburg', 52.3514000, 13.4939000, 'active', '2026-01-31 19:18:45', '2026-01-31 19:18:45'),
(2617, 'CBU', 'EDCD', 'Cottbus-Drewitz Airport', NULL, 'DE', 'Brandenburg', 51.8894000, 14.5319000, 'active', '2026-01-31 19:18:46', '2026-01-31 19:18:46'),
(2618, 'BRE', 'EDDW', 'Bremen Airport', NULL, 'DE', 'Bremen', 53.0475000, 8.7866700, 'active', '2026-01-31 19:18:46', '2026-01-31 19:18:46'),
(2619, 'BRV', 'EDWB', 'Bremerhaven Airport', NULL, 'DE', 'Bremen', 53.5069000, 8.5727800, 'active', '2026-01-31 19:18:46', '2026-01-31 19:18:46'),
(2620, 'HAM', 'EDDH', 'Hamburg Airport', NULL, 'DE', 'Hamburg', 53.6304000, 9.9882300, 'active', '2026-01-31 19:18:47', '2026-01-31 19:18:47'),
(2621, 'XFW', 'EDHI', 'Hamburg Finkenwerder Airport', NULL, 'DE', 'Hamburg', 53.5353000, 9.8355600, 'active', '2026-01-31 19:18:47', '2026-01-31 19:18:47'),
(2622, 'FRA', 'EDDF', 'Frankfurt Airport', NULL, 'DE', 'Hessen', 50.0333000, 8.5705600, 'active', '2026-01-31 19:18:47', '2026-01-31 19:18:47'),
(2623, 'FRZ', 'ETHF', 'Fritzlar Air Base', NULL, 'DE', 'Hessen', 51.1146000, 9.2860000, 'active', '2026-01-31 19:18:48', '2026-01-31 19:18:48'),
(2624, 'KSF', 'EDVK', 'Kassel Airport', NULL, 'DE', 'Hessen', 51.4173000, 9.3849700, 'active', '2026-01-31 19:18:48', '2026-01-31 19:18:48'),
(2625, 'WIE', 'ETOU', 'Wiesbaden Army Airfield', NULL, 'DE', 'Hessen', 50.0498000, 8.3254000, 'active', '2026-01-31 19:18:48', '2026-01-31 19:18:48'),
(2626, 'BBH', 'EDBH', 'Stralsund-Barth Airport', NULL, 'DE', 'Mecklenburg-Vorpommern', 54.3383000, 12.7105000, 'active', '2026-01-31 19:18:49', '2026-01-31 19:18:49'),
(2627, 'FNB', 'EDBN', 'Neubrandenburg Airport', NULL, 'DE', 'Mecklenburg-Vorpommern', 53.6022000, 13.3060000, 'active', '2026-01-31 19:18:49', '2026-01-31 19:18:49'),
(2628, 'GTI', 'EDCG', 'Rugen Airport (Guttin Airfield)', NULL, 'DE', 'Mecklenburg-Vorpommern', 54.3833000, 13.3256000, 'active', '2026-01-31 19:18:49', '2026-01-31 19:18:49'),
(2629, 'HDF', 'EDAH', 'Heringsdorf Airport', NULL, 'DE', 'Mecklenburg-Vorpommern', 53.8787000, 14.1523000, 'active', '2026-01-31 19:18:50', '2026-01-31 19:18:50'),
(2630, 'PEF', 'EDCP', 'Peenemunde Airfield', NULL, 'DE', 'Mecklenburg-Vorpommern', 54.1578000, 13.7744000, 'active', '2026-01-31 19:18:50', '2026-01-31 19:18:50'),
(2631, 'REB', 'EDAX', 'Rechlin-Larz Airfield', NULL, 'DE', 'Mecklenburg-Vorpommern', 53.3064000, 12.7522000, 'active', '2026-01-31 19:18:50', '2026-01-31 19:18:50'),
(2632, 'RLG', 'ETNL', 'Rostock-Laage Airport', NULL, 'DE', 'Mecklenburg-Vorpommern', 53.9182000, 12.2783000, 'active', '2026-01-31 19:18:51', '2026-01-31 19:18:51'),
(2633, 'SZW', 'EDOP', 'Schwerin-Parchim International Airport', NULL, 'DE', 'Mecklenburg-Vorpommern', 53.4270000, 11.7834000, 'active', '2026-01-31 19:18:51', '2026-01-31 19:18:51'),
(2634, 'AGE', 'EDWG', 'Wangerooge Airport', NULL, 'DE', 'Niedersachsen', 53.7828000, 7.9138900, 'active', '2026-01-31 19:18:51', '2026-01-31 19:18:51'),
(2635, 'BMK', 'EDWR', 'Borkum Airfield', NULL, 'DE', 'Niedersachsen', 53.5964000, 6.7091700, 'active', '2026-01-31 19:18:52', '2026-01-31 19:18:52'),
(2636, 'BMR', 'EDWZ', 'Baltrum Airport', NULL, 'DE', 'Niedersachsen', 53.7247000, 7.3733300, 'active', '2026-01-31 19:18:52', '2026-01-31 19:18:52'),
(2637, 'BWE', 'EDVE', 'Braunschweig-Wolfsburg Airport', NULL, 'DE', 'Niedersachsen', 52.3192000, 10.5561000, 'active', '2026-01-31 19:18:52', '2026-01-31 19:18:52'),
(2638, 'EME', 'EDWE', 'Emden Airport', NULL, 'DE', 'Niedersachsen', 53.3911000, 7.2275000, 'active', '2026-01-31 19:18:53', '2026-01-31 19:18:53'),
(2639, 'FCN', 'ETMN', 'Nordholz Naval Airbase', NULL, 'DE', 'Niedersachsen', 53.7677000, 8.6585000, 'active', '2026-01-31 19:18:53', '2026-01-31 19:18:53'),
(2640, 'HAJ', 'EDDV', 'Hannover Airport', NULL, 'DE', 'Niedersachsen', 52.4611000, 9.6850800, 'active', '2026-01-31 19:18:53', '2026-01-31 19:18:53'),
(2641, 'JUI', 'EDWJ', 'Juist Airport', NULL, 'DE', 'Niedersachsen', 53.6811000, 7.0558300, 'active', '2026-01-31 19:18:54', '2026-01-31 19:18:54'),
(2642, 'LGO', 'EDWL', 'Langeoog Airport', NULL, 'DE', 'Niedersachsen', 53.7425000, 7.4977800, 'active', '2026-01-31 19:18:54', '2026-01-31 19:18:54'),
(2643, 'NOD', 'EDWS', 'Norddeich Airport', NULL, 'DE', 'Niedersachsen', 53.6331000, 7.1902800, 'active', '2026-01-31 19:18:54', '2026-01-31 19:18:54'),
(2644, 'NRD', 'EDWY', 'Norderney Airport', NULL, 'DE', 'Niedersachsen', 53.7069000, 7.2300000, 'active', '2026-01-31 19:18:55', '2026-01-31 19:18:55'),
(2645, 'VAC', 'EDWU', 'Varrelbusch Airport', NULL, 'DE', 'Niedersachsen', 52.9083000, 8.0405600, 'active', '2026-01-31 19:18:55', '2026-01-31 19:18:55'),
(2646, 'WVN', 'EDWI', 'JadeWeserAirport', NULL, 'DE', 'Niedersachsen', 53.5022000, 8.0522200, 'active', '2026-01-31 19:18:55', '2026-01-31 19:18:55'),
(2647, 'XLW', 'EDWD', 'Lemwerder Airport', NULL, 'DE', 'Niedersachsen', 53.1447000, 8.6244400, 'active', '2026-01-31 19:18:56', '2026-01-31 19:18:56'),
(2648, 'AAH', 'EDKA', 'Merzbruck Airport', NULL, 'DE', 'Nordrhein-Westfalen', 50.8231000, 6.1863900, 'active', '2026-01-31 19:18:56', '2026-01-31 19:18:56'),
(2649, 'BFE', 'EDLI', 'Bielefeld Airport', NULL, 'DE', 'Nordrhein-Westfalen', 51.9647000, 8.5444400, 'active', '2026-01-31 19:18:56', '2026-01-31 19:18:56'),
(2650, 'CGN', 'EDDK', 'Cologne Bonn Airport', NULL, 'DE', 'Nordrhein-Westfalen', 50.8659000, 7.1427400, 'active', '2026-01-31 19:18:57', '2026-01-31 19:18:57'),
(2651, 'ZCV', 'EDLD', 'Dinslaken/Schwarze Heide', NULL, 'DE', 'Nordrhein-Westfalen', 51.6160000, 6.8611670, 'active', '2026-01-31 19:18:57', '2026-01-31 19:18:57'),
(2652, 'DTM', 'EDLW', 'Dortmund Airport', NULL, 'DE', 'Nordrhein-Westfalen', 51.5183000, 7.6122400, 'active', '2026-01-31 19:18:57', '2026-01-31 19:18:57'),
(2653, 'DUS', 'EDDL', 'Dusseldorf Airport', NULL, 'DE', 'Nordrhein-Westfalen', 51.2895000, 6.7667800, 'active', '2026-01-31 19:18:58', '2026-01-31 19:18:58'),
(2654, 'ESS', 'EDLE', 'Essen/Mulheim Airport', NULL, 'DE', 'Nordrhein-Westfalen', 51.4023000, 6.9373300, 'active', '2026-01-31 19:18:58', '2026-01-31 19:18:58'),
(2655, 'FMO', 'EDDG', 'Munster Osnabruck International Airport', NULL, 'DE', 'Nordrhein-Westfalen', 52.1346000, 7.6848300, 'active', '2026-01-31 19:18:58', '2026-01-31 19:18:58'),
(2656, 'GKE', 'ETNG', 'NATO Air Base Geilenkirchen', NULL, 'DE', 'Nordrhein-Westfalen', 50.9608000, 6.0424200, 'active', '2026-01-31 19:18:59', '2026-01-31 19:18:59'),
(2657, 'GUT', 'ETUO', 'RAF Gutersloh', NULL, 'DE', 'Nordrhein-Westfalen', 51.9228000, 8.3063300, 'active', '2026-01-31 19:18:59', '2026-01-31 19:18:59'),
(2658, 'MGL', 'EDLN', 'Dusseldorf Monchengladbach Airport', NULL, 'DE', 'Nordrhein-Westfalen', 51.2303000, 6.5044400, 'active', '2026-01-31 19:18:59', '2026-01-31 19:18:59'),
(2659, 'NRN', 'EDLV', 'Weeze Airport (Niederrhein Airport)', NULL, 'DE', 'Nordrhein-Westfalen', 51.6024000, 6.1421700, 'active', '2026-01-31 19:19:00', '2026-01-31 19:19:00'),
(2660, 'PAD', 'EDLP', 'Paderborn Lippstadt Airport', NULL, 'DE', 'Nordrhein-Westfalen', 51.6141000, 8.6163200, 'active', '2026-01-31 19:19:00', '2026-01-31 19:19:00'),
(2661, 'SGE', 'EDGS', 'Siegerland Airport', NULL, 'DE', 'Nordrhein-Westfalen', 50.7077000, 8.0829700, 'active', '2026-01-31 19:19:00', '2026-01-31 19:19:00'),
(2662, 'BBJ', 'EDRB', 'Bitburg Airport', NULL, 'DE', 'Rheinland-Pfalz', 49.9453000, 6.5650000, 'active', '2026-01-31 19:19:01', '2026-01-31 19:19:01'),
(2663, 'HHN', 'EDFH', 'Frankfurt-Hahn Airport', NULL, 'DE', 'Rheinland-Pfalz', 49.9487000, 7.2638900, 'active', '2026-01-31 19:19:01', '2026-01-31 19:19:01'),
(2664, 'RMS', 'ETAR', 'Ramstein Air Base', NULL, 'DE', 'Rheinland-Pfalz', 49.4369000, 7.6002800, 'active', '2026-01-31 19:19:01', '2026-01-31 19:19:01'),
(2665, 'SPM', 'ETAD', 'Spangdahlem Air Base', NULL, 'DE', 'Rheinland-Pfalz', 49.9727000, 6.6925000, 'active', '2026-01-31 19:19:02', '2026-01-31 19:19:02'),
(2666, 'ZQW', 'EDRZ', 'Zweibrucken Airport', NULL, 'DE', 'Rheinland-Pfalz', 49.2094000, 7.4005600, 'active', '2026-01-31 19:19:02', '2026-01-31 19:19:02'),
(2667, 'SCN', 'EDDR', 'Saarbrucken Airport', NULL, 'DE', 'Saarland', 49.2146000, 7.1095100, 'active', '2026-01-31 19:19:02', '2026-01-31 19:19:02'),
(2668, 'DRS', 'EDDC', 'Dresden Airport', NULL, 'DE', 'Sachsen', 51.1328000, 13.7672000, 'active', '2026-01-31 19:19:03', '2026-01-31 19:19:03'),
(2669, 'IES', 'EDAU', 'Riesa-Gohlis Airfield', NULL, 'DE', 'Sachsen', 51.2936000, 13.3561000, 'active', '2026-01-31 19:19:03', '2026-01-31 19:19:03'),
(2670, 'LEJ', 'EDDP', 'Leipzig/Halle Airport', NULL, 'DE', 'Sachsen', 51.4239000, 12.2364000, 'active', '2026-01-31 19:19:03', '2026-01-31 19:19:03'),
(2671, 'CSO', 'EDBC', 'Magdeburg-Cochstedt Airport', NULL, 'DE', 'Sachsen-Anhalt', 51.8564000, 11.4203000, 'active', '2026-01-31 19:19:04', '2026-01-31 19:19:04'),
(2672, 'KOQ', 'EDCK', 'Kothen Airport', NULL, 'DE', 'Sachsen-Anhalt', 51.7211000, 11.9528000, 'active', '2026-01-31 19:19:04', '2026-01-31 19:19:04'),
(2673, 'ZHZ', 'EDAQ', 'Halle-Oppin Airport', NULL, 'DE', 'Sachsen-Anhalt', 51.5527000, 12.0540000, 'active', '2026-01-31 19:19:04', '2026-01-31 19:19:04'),
(2674, 'EUM', 'EDHN', 'Neumunster Airport', NULL, 'DE', 'Schleswig-Holstein', 54.0794000, 9.9413900, 'active', '2026-01-31 19:19:05', '2026-01-31 19:19:05'),
(2675, 'FLF', 'EDXF', 'Flensburg-Schaferhaus Airport', NULL, 'DE', 'Schleswig-Holstein', 54.7733000, 9.3788900, 'active', '2026-01-31 19:19:05', '2026-01-31 19:19:05'),
(2676, 'GWT', 'EDXW', 'Sylt Airport (Westerland Airport)', NULL, 'DE', 'Schleswig-Holstein', 54.9132000, 8.3404700, 'active', '2026-01-31 19:19:05', '2026-01-31 19:19:05'),
(2677, 'HEI', 'EDXB', 'Heide-Busum Airport', NULL, 'DE', 'Schleswig-Holstein', 54.1533000, 8.9016700, 'active', '2026-01-31 19:19:06', '2026-01-31 19:19:06'),
(2678, 'HGL', 'EDXH', 'Helgoland Airport (Dune Airport)', NULL, 'DE', 'Schleswig-Holstein', 54.1853000, 7.9158300, 'active', '2026-01-31 19:19:06', '2026-01-31 19:19:06'),
(2679, 'KEL', 'EDHK', 'Kiel Airport', NULL, 'DE', 'Schleswig-Holstein', 54.3794000, 10.1453000, 'active', '2026-01-31 19:19:06', '2026-01-31 19:19:06'),
(2680, 'LBC', 'EDHL', 'Lubeck Airport', NULL, 'DE', 'Schleswig-Holstein', 53.8054000, 10.7192000, 'active', '2026-01-31 19:19:07', '2026-01-31 19:19:07'),
(2681, 'OHR', 'EDXY', 'Wyk auf Fohr Airport', NULL, 'DE', 'Schleswig-Holstein', 54.6844000, 8.5283300, 'active', '2026-01-31 19:19:07', '2026-01-31 19:19:07'),
(2682, 'PSH', 'EDXO', 'Sankt Peter-Ording Airport', NULL, 'DE', 'Schleswig-Holstein', 54.3089000, 8.6869400, 'active', '2026-01-31 19:19:07', '2026-01-31 19:19:07'),
(2683, 'QHU', 'EDXJ', 'Husum Schwesing Airport', NULL, 'DE', 'Schleswig-Holstein', 54.5100000, 9.1383300, 'active', '2026-01-31 19:19:08', '2026-01-31 19:19:08'),
(2684, 'WBG', 'ETNS', 'Schleswig Air Base', NULL, 'DE', 'Schleswig-Holstein', 54.4593000, 9.5163300, 'active', '2026-01-31 19:19:08', '2026-01-31 19:19:08'),
(2685, 'AOC', 'EDAC', 'Leipzig-Altenburg Airport', NULL, 'DE', 'Thuringen', 50.9819000, 12.5064000, 'active', '2026-01-31 19:19:08', '2026-01-31 19:19:08'),
(2686, 'EIB', 'EDGE', 'Eisenach-Kindel Airport', NULL, 'DE', 'Thuringen', 50.9916000, 10.4797000, 'active', '2026-01-31 19:19:09', '2026-01-31 19:19:09'),
(2687, 'ERF', 'EDDE', 'Erfurt-Weimar Airport', NULL, 'DE', 'Thuringen', 50.9798000, 10.9581000, 'active', '2026-01-31 19:19:09', '2026-01-31 19:19:09'),
(2688, 'AII', 'HDAS', 'Ali-Sabieh Airport', NULL, 'DJ', 'Ali Sabieh', 11.1469000, 42.7200000, 'active', '2026-01-31 19:19:09', '2026-01-31 19:19:09'),
(2689, 'JIB', 'HDAM', 'Djibouti-Ambouli International Airport', NULL, 'DJ', 'Djibouti', 11.5473000, 43.1595000, 'active', '2026-01-31 19:19:10', '2026-01-31 19:19:10'),
(2690, 'OBC', 'HDOB', 'Obock Airport', NULL, 'DJ', 'Obock', 11.9670000, 43.2670000, 'active', '2026-01-31 19:19:10', '2026-01-31 19:19:10'),
(2691, 'MHI', 'HDMO', 'Moucha Airport', NULL, 'DJ', 'Tadjourah', 11.7167000, 43.2000000, 'active', '2026-01-31 19:19:11', '2026-01-31 19:19:11'),
(2692, 'TDJ', 'HDTJ', 'Tadjoura Airport', NULL, 'DJ', 'Tadjourah', 11.7830000, 42.9170000, 'active', '2026-01-31 19:19:11', '2026-01-31 19:19:11'),
(2693, 'CPH', 'EKCH', 'Copenhagen Airport', NULL, 'DK', 'Hovedstaden', 55.6179000, 12.6560000, 'active', '2026-01-31 19:19:11', '2026-01-31 19:19:11'),
(2694, 'RNN', 'EKRN', 'Bornholm Airport', NULL, 'DK', 'Hovedstaden', 55.0633000, 14.7596000, 'active', '2026-01-31 19:19:12', '2026-01-31 19:19:12'),
(2695, 'AAR', 'EKAH', 'Aarhus Airport', NULL, 'DK', 'Midtjylland', 56.3000000, 10.6190000, 'active', '2026-01-31 19:19:12', '2026-01-31 19:19:12'),
(2696, 'KRP', 'EKKA', 'Karup Airport', NULL, 'DK', 'Midtjylland', 56.2975000, 9.1246300, 'active', '2026-01-31 19:19:12', '2026-01-31 19:19:12'),
(2697, 'SQW', 'EKSV', 'Skive Airport', NULL, 'DK', 'Midtjylland', 56.5502000, 9.1729800, 'active', '2026-01-31 19:19:13', '2026-01-31 19:19:13'),
(2698, 'STA', 'EKVJ', 'Stauning Vestjylland Airport', NULL, 'DK', 'Midtjylland', 55.9901000, 8.3539100, 'active', '2026-01-31 19:19:13', '2026-01-31 19:19:13'),
(2699, 'AAL', 'EKYT', 'Aalborg Airport', NULL, 'DK', 'Nordjylland', 57.0928000, 9.8492400, 'active', '2026-01-31 19:19:13', '2026-01-31 19:19:13'),
(2700, 'BYR', 'EKLS', 'Laesoe Airport', NULL, 'DK', 'Nordjylland', 57.2772000, 11.0001000, 'active', '2026-01-31 19:19:14', '2026-01-31 19:19:14'),
(2701, 'CNL', 'EKSN', 'Sindal Airport', NULL, 'DK', 'Nordjylland', 57.5035000, 10.2294000, 'active', '2026-01-31 19:19:14', '2026-01-31 19:19:14'),
(2702, 'TED', 'EKTS', 'Thisted Airport', NULL, 'DK', 'Nordjylland', 57.0688000, 8.7052200, 'active', '2026-01-31 19:19:14', '2026-01-31 19:19:14'),
(2703, 'MRW', 'EKMB', 'Lolland Falster Airport', NULL, 'DK', 'Sjaelland', 54.6993000, 11.4401000, 'active', '2026-01-31 19:19:15', '2026-01-31 19:19:15'),
(2704, 'RKE', 'EKRK', 'Roskilde Airport', NULL, 'DK', 'Sjaelland', 55.5856000, 12.1314000, 'active', '2026-01-31 19:19:15', '2026-01-31 19:19:15'),
(2705, 'BLL', 'EKBI', 'Billund Airport', NULL, 'DK', 'Syddanmark', 55.7403000, 9.1517800, 'active', '2026-01-31 19:19:15', '2026-01-31 19:19:15'),
(2706, 'EBJ', 'EKEB', 'Esbjerg Airport', NULL, 'DK', 'Syddanmark', 55.5259000, 8.5534000, 'active', '2026-01-31 19:19:16', '2026-01-31 19:19:16'),
(2707, 'ODE', 'EKOD', 'Hans Christian Andersen Airport', NULL, 'DK', 'Syddanmark', 55.4767000, 10.3309000, 'active', '2026-01-31 19:19:16', '2026-01-31 19:19:16'),
(2708, 'SGD', 'EKSB', 'Sonderborg Airport', NULL, 'DK', 'Syddanmark', 54.9644000, 9.7917300, 'active', '2026-01-31 19:19:16', '2026-01-31 19:19:16'),
(2709, 'SKS', 'EKSP', 'Vojens Airport (Skrydstrup Airport)', NULL, 'DK', 'Syddanmark', 55.2210000, 9.2670200, 'active', '2026-01-31 19:19:17', '2026-01-31 19:19:17'),
(2710, 'DOM', 'TDPD', 'Douglas-Charles Airport', NULL, 'DM', 'Saint Andrew', 15.5470000, -61.3000000, 'active', '2026-01-31 19:19:17', '2026-01-31 19:19:17'),
(2711, 'DCF', 'TDCF', 'Canefield Airport', NULL, 'DM', 'Saint George', 15.3367000, -61.3922000, 'active', '2026-01-31 19:19:17', '2026-01-31 19:19:17'),
(2712, 'BRX', 'MDBH', 'Maria Montez International Airport', NULL, 'DO', 'Barahona', 18.2515000, -71.1204000, 'active', '2026-01-31 19:19:18', '2026-01-31 19:19:18'),
(2713, 'JBQ', 'MDJB', 'La Isabela International Airport (Dr. Joaquin Balaguer Int\'l)', NULL, 'DO', 'Distrito Nacional (Santo Domingo)', 18.5725000, -69.9856000, 'active', '2026-01-31 19:19:18', '2026-01-31 19:19:18'),
(2714, 'PUJ', 'MDPC', 'Punta Cana International Airport', NULL, 'DO', 'La Altagracia', 18.5674000, -68.3634000, 'active', '2026-01-31 19:19:18', '2026-01-31 19:19:18'),
(2715, 'COZ', 'MDCZ', 'Constanza Airport', NULL, 'DO', 'La Vega', 18.9075000, -70.7219000, 'active', '2026-01-31 19:19:19', '2026-01-31 19:19:19'),
(2716, 'SDQ', 'MDSD', 'Las Americas International Airport', NULL, 'DO', 'Monte Plata', 18.4297000, -69.6689000, 'active', '2026-01-31 19:19:19', '2026-01-31 19:19:19'),
(2717, 'CBJ', 'MDCR', 'Cabo Rojo Airport', NULL, 'DO', 'Pedernales', 17.9290000, -71.6448000, 'active', '2026-01-31 19:19:19', '2026-01-31 19:19:19'),
(2718, 'POP', 'MDPP', 'Gregorio Luperon International Airport', NULL, 'DO', 'Puerto Plata', 19.7579000, -70.5700000, 'active', '2026-01-31 19:19:20', '2026-01-31 19:19:20'),
(2719, 'AZS', 'MDCY', 'Samana El Catey International Airport', NULL, 'DO', 'Samana', 19.2670000, -69.7420000, 'active', '2026-01-31 19:19:20', '2026-01-31 19:19:20'),
(2720, 'EPS', 'MDAB', 'Arroyo Barril Airport', NULL, 'DO', 'Samana', 19.3214000, -69.4959000, 'active', '2026-01-31 19:19:20', '2026-01-31 19:19:20'),
(2721, 'STI', 'MDST', 'Cibao International Airport', NULL, 'DO', 'Santiago', 19.4061000, -70.6047000, 'active', '2026-01-31 19:19:21', '2026-01-31 19:19:21'),
(2722, 'AZR', 'DAUA', 'Touat-Cheikh Sidi Mohamed Belkebir Airport', NULL, 'DZ', 'Adrar', 27.8376000, -0.1864140, 'active', '2026-01-31 19:19:21', '2026-01-31 19:19:21'),
(2723, 'BMW', 'DATM', 'Bordj Mokhtar Airport', NULL, 'DZ', 'Adrar', 21.3750000, 0.9238890, 'active', '2026-01-31 19:19:21', '2026-01-31 19:19:21'),
(2724, 'TMX', 'DAUT', 'Timimoun Airport', NULL, 'DZ', 'Adrar', 29.2371000, 0.2760330, 'active', '2026-01-31 19:19:22', '2026-01-31 19:19:22'),
(2725, 'ALG', 'DAAG', 'Houari Boumediene Airport', NULL, 'DZ', 'Alger', 36.6910000, 3.2154100, 'active', '2026-01-31 19:19:22', '2026-01-31 19:19:22'),
(2726, 'AAE', 'DABB', 'Rabah Bitat Airport (Les Salines Airport)', NULL, 'DZ', 'Annaba', 36.8222000, 7.8091700, 'active', '2026-01-31 19:19:22', '2026-01-31 19:19:22'),
(2727, 'BLJ', 'DABT', 'Mostepha Ben Boulaid Airport', NULL, 'DZ', 'Batna', 35.7521000, 6.3085900, 'active', '2026-01-31 19:19:23', '2026-01-31 19:19:23'),
(2728, 'CBH', 'DAOR', 'Boudghene Ben Ali Lotfi Airport', NULL, 'DZ', 'Bechar', 31.6457000, -2.2698600, 'active', '2026-01-31 19:19:23', '2026-01-31 19:19:23'),
(2729, 'BJA', 'DAAE', 'Soummam - Abane Ramdane Airport', NULL, 'DZ', 'Bejaia', 36.7120000, 5.0699200, 'active', '2026-01-31 19:19:23', '2026-01-31 19:19:23'),
(2730, 'BSK', 'DAUB', 'Biskra Airport', NULL, 'DZ', 'Biskra', 34.7933000, 5.7382300, 'active', '2026-01-31 19:19:24', '2026-01-31 19:19:24'),
(2731, 'CFK', 'DAOI', 'Chlef International Airport', NULL, 'DZ', 'Chlef', 36.2127000, 1.3317700, 'active', '2026-01-31 19:19:24', '2026-01-31 19:19:24'),
(2732, 'CZL', 'DABC', 'Mohamed Boudiaf International Airport', NULL, 'DZ', 'Constantine', 36.2760000, 6.6203900, 'active', '2026-01-31 19:19:25', '2026-01-31 19:19:25'),
(2733, 'BUJ', 'DAAD', 'Bou Saada Airport', NULL, 'DZ', 'Djelfa', 35.3325000, 4.2063900, 'active', '2026-01-31 19:19:25', '2026-01-31 19:19:25'),
(2734, 'EBH', 'DAOY', 'El Bayadh Airport', NULL, 'DZ', 'El Bayadh', 33.7217000, 1.0925000, 'active', '2026-01-31 19:19:25', '2026-01-31 19:19:25'),
(2735, 'ELU', 'DAUO', 'Guemar Airport', NULL, 'DZ', 'El Oued', 33.5114000, 6.7767900, 'active', '2026-01-31 19:19:26', '2026-01-31 19:19:26'),
(2736, 'ELG', 'DAUE', 'El Golea Airport', NULL, 'DZ', 'Ghardaia', 30.5713000, 2.8595900, 'active', '2026-01-31 19:19:26', '2026-01-31 19:19:26'),
(2737, 'GHA', 'DAUG', 'Noumerat - Moufdi Zakaria Airport', NULL, 'DZ', 'Ghardaia', 32.3841000, 3.7941100, 'active', '2026-01-31 19:19:26', '2026-01-31 19:19:26'),
(2738, 'DJG', 'DAAJ', 'Tiska Djanet Airport', NULL, 'DZ', 'Illizi', 24.2928000, 9.4524400, 'active', '2026-01-31 19:19:27', '2026-01-31 19:19:27'),
(2739, 'IAM', 'DAUZ', 'In Amenas Airport (Zarzaitine Airport)', NULL, 'DZ', 'Illizi', 28.0515000, 9.6429100, 'active', '2026-01-31 19:19:27', '2026-01-31 19:19:27'),
(2740, 'VVZ', 'DAAP', 'Takhamalt Airport', NULL, 'DZ', 'Illizi', 26.7235000, 8.6226500, 'active', '2026-01-31 19:19:27', '2026-01-31 19:19:27'),
(2741, 'GJL', 'DAAV', 'Jijel Ferhat Abbas Airport', NULL, 'DZ', 'Jijel', 36.7951000, 5.8736100, 'active', '2026-01-31 19:19:28', '2026-01-31 19:19:28'),
(2742, 'HRM', 'DAFH', 'Hassi R\'Mel Airport (Tilrempt Airport)', NULL, 'DZ', 'Laghouat', 32.9304000, 3.3115400, 'active', '2026-01-31 19:19:28', '2026-01-31 19:19:28'),
(2743, 'LOO', 'DAUL', 'L\'Mekrareg Airport (Laghouat Airport)', NULL, 'DZ', 'Laghouat', 33.7644000, 2.9283400, 'active', '2026-01-31 19:19:28', '2026-01-31 19:19:28'),
(2744, 'MUW', 'DAOV', 'Ghriss Airport', NULL, 'DZ', 'Mascara', 35.2077000, 0.1471420, 'active', '2026-01-31 19:19:29', '2026-01-31 19:19:29'),
(2745, 'MQV', NULL, 'Mostaganem Airport', NULL, 'DZ', 'Mostaganem', 35.9088000, 0.1493830, 'active', '2026-01-31 19:19:29', '2026-01-31 19:19:29'),
(2746, 'MZW', 'DAAY', 'Mecheria Airport', NULL, 'DZ', 'Naama', 33.5359000, -0.2423530, 'active', '2026-01-31 19:19:29', '2026-01-31 19:19:29'),
(2747, 'ORN', 'DAOO', 'Oran Es Senia Airport', NULL, 'DZ', 'Oran', 35.6239000, -0.6211830, 'active', '2026-01-31 19:19:30', '2026-01-31 19:19:30'),
(2748, 'TAF', 'DAOL', 'Oran Tafaraoui Airport', NULL, 'DZ', 'Oran', 35.5424000, -0.5322780, 'active', '2026-01-31 19:19:30', '2026-01-31 19:19:30'),
(2749, 'HME', 'DAUH', 'Oued Irara-Krim Belkacem Airport', NULL, 'DZ', 'Ouargla', 31.6730000, 6.1404400, 'active', '2026-01-31 19:19:30', '2026-01-31 19:19:30'),
(2750, 'OGX', 'DAUU', 'Ain Beida Airport', NULL, 'DZ', 'Ouargla', 31.9172000, 5.4127800, 'active', '2026-01-31 19:19:31', '2026-01-31 19:19:31'),
(2751, 'TGR', 'DAUK', 'Sidi Mahdi Airport', NULL, 'DZ', 'Ouargla', 33.0678000, 6.0886700, 'active', '2026-01-31 19:19:31', '2026-01-31 19:19:31'),
(2752, 'QSF', 'DAAS', 'Ain Arnat Airport', NULL, 'DZ', 'Setif', 36.1781000, 5.3244900, 'active', '2026-01-31 19:19:31', '2026-01-31 19:19:31'),
(2753, 'BFW', 'DAOS', 'Sidi Bel Abbes Airport', NULL, 'DZ', 'Sidi Bel Abbes', 35.1718000, -0.5932750, 'active', '2026-01-31 19:19:32', '2026-01-31 19:19:32'),
(2754, 'SKI', 'DABP', 'Skikda Airport', NULL, 'DZ', 'Skikda', 36.8641000, 6.9516000, 'active', '2026-01-31 19:19:32', '2026-01-31 19:19:32'),
(2755, 'INF', 'DATG', 'In Guezzam Airport', NULL, 'DZ', 'Tamanrasset', 19.5670000, 5.7500000, 'active', '2026-01-31 19:19:32', '2026-01-31 19:19:32'),
(2756, 'INZ', 'DAUI', 'In Salah Airport', NULL, 'DZ', 'Tamanrasset', 27.2510000, 2.5120200, 'active', '2026-01-31 19:19:33', '2026-01-31 19:19:33'),
(2757, 'TMR', 'DAAT', 'Aguenar -Hadj Bey Akhamok Airport', NULL, 'DZ', 'Tamanrasset', 22.8115000, 5.4510800, 'active', '2026-01-31 19:19:33', '2026-01-31 19:19:33'),
(2758, 'TEE', 'DABS', 'Cheikh Larbi Tebessi Airport', NULL, 'DZ', 'Tebessa', 35.4316000, 8.1207200, 'active', '2026-01-31 19:19:33', '2026-01-31 19:19:33'),
(2759, 'TID', 'DAOB', 'Abdelhafid Boussouf Bou Chekif Airport', NULL, 'DZ', 'Tiaret', 35.3411000, 1.4631500, 'active', '2026-01-31 19:19:34', '2026-01-31 19:19:34'),
(2760, 'TIN', 'DAOF', 'Tindouf Airport', NULL, 'DZ', 'Tindouf', 27.7004000, -8.1671000, 'active', '2026-01-31 19:19:34', '2026-01-31 19:19:34'),
(2761, 'TLM', 'DAON', 'Zenata - Messali El Hadj Airport', NULL, 'DZ', 'Tlemcen', 35.0167000, -1.4500000, 'active', '2026-01-31 19:19:34', '2026-01-31 19:19:34'),
(2762, 'CUE', 'SECU', 'Mariscal Lamar International Airport', NULL, 'EC', 'Azuay', -2.8894700, -78.9844000, 'active', '2026-01-31 19:19:35', '2026-01-31 19:19:35'),
(2763, 'TUA', 'SETU', 'Teniente Coronel Luis a Mantilla International Airport', NULL, 'EC', 'Carchi', 0.8095060, -77.7081000, 'active', '2026-01-31 19:19:35', '2026-01-31 19:19:35'),
(2764, 'LTX', NULL, 'Cotopaxi International Airport', NULL, 'EC', 'Cotopaxi', -0.9068330, -78.6158000, 'active', '2026-01-31 19:19:35', '2026-01-31 19:19:35'),
(2765, 'ETR', 'SERO', 'Santa Rosa International Airport', NULL, 'EC', 'El Oro', -3.4419900, -79.9970000, 'active', '2026-01-31 19:19:36', '2026-01-31 19:19:36'),
(2766, 'MCH', 'SEMH', 'General Manuel Serrano Airport', NULL, 'EC', 'El Oro', -3.2689000, -79.9616000, 'active', '2026-01-31 19:19:36', '2026-01-31 19:19:36'),
(2767, 'ESM', 'SETN', 'Carlos Concha Torres International Airport', NULL, 'EC', 'Esmeraldas', 0.9785190, -79.6266000, 'active', '2026-01-31 19:19:36', '2026-01-31 19:19:36'),
(2768, 'GPS', 'SEGS', 'Seymour Airport', NULL, 'EC', 'Galapagos', -0.4537580, -90.2659000, 'active', '2026-01-31 19:19:37', '2026-01-31 19:19:37'),
(2769, 'IBB', 'SEII', 'General Villamil Airport', NULL, 'EC', 'Galapagos', -0.9426280, -90.9530000, 'active', '2026-01-31 19:19:37', '2026-01-31 19:19:37'),
(2770, 'SCY', 'SEST', 'San Cristobal Airport', NULL, 'EC', 'Galapagos', -0.9102060, -89.6174000, 'active', '2026-01-31 19:19:37', '2026-01-31 19:19:37'),
(2771, 'GYE', 'SEGU', 'Jose Joaquin de Olmedo International Airport', NULL, 'EC', 'Guayas', -2.1574200, -79.8836000, 'active', '2026-01-31 19:19:38', '2026-01-31 19:19:38'),
(2772, 'LOH', 'SETM', 'Ciudad de Catamayo Airport', NULL, 'EC', 'Loja', -3.9958900, -79.3719000, 'active', '2026-01-31 19:19:38', '2026-01-31 19:19:38'),
(2773, 'MRR', 'SEMA', 'Jose Maria Velasco Ibarra Airport', NULL, 'EC', 'Loja', -4.3782300, -79.9410000, 'active', '2026-01-31 19:19:38', '2026-01-31 19:19:38'),
(2774, 'BHA', 'SESV', 'Los Perales Airport', NULL, 'EC', 'Manabi', -0.6081110, -80.4027000, 'active', '2026-01-31 19:19:39', '2026-01-31 19:19:39'),
(2775, 'JIP', 'SEJI', 'Jipijapa Airport', NULL, 'EC', 'Manabi', -1.0000000, -80.6667000, 'active', '2026-01-31 19:19:39', '2026-01-31 19:19:39'),
(2776, 'MEC', 'SEMT', 'Eloy Alfaro International Airport', NULL, 'EC', 'Manabi', -0.9460780, -80.6788000, 'active', '2026-01-31 19:19:39', '2026-01-31 19:19:39'),
(2777, 'PVO', 'SEPV', 'Reales Tamarindos Airport', NULL, 'EC', 'Manabi', -1.0416500, -80.4722000, 'active', '2026-01-31 19:19:40', '2026-01-31 19:19:40'),
(2778, 'MZD', NULL, 'Mendez Airport', NULL, 'EC', 'Morona Santiago', -2.7333300, -78.3167000, 'active', '2026-01-31 19:19:40', '2026-01-31 19:19:40'),
(2779, 'SUQ', 'SESC', 'Sucua Airport', NULL, 'EC', 'Morona Santiago', -2.4830000, -78.1670000, 'active', '2026-01-31 19:19:40', '2026-01-31 19:19:40'),
(2780, 'TSC', 'SETH', 'Taisha Airport', NULL, 'EC', 'Morona Santiago', -2.3816700, -77.5028000, 'active', '2026-01-31 19:19:41', '2026-01-31 19:19:41'),
(2781, 'XMS', 'SEMC', 'Edmundo Carvajal Airport', NULL, 'EC', 'Morona Santiago', -2.2991700, -78.1208000, 'active', '2026-01-31 19:19:41', '2026-01-31 19:19:41'),
(2782, 'TNW', 'SEJD', 'Jumandy Airport', NULL, 'EC', 'Napo', -1.0597200, -77.5833000, 'active', '2026-01-31 19:19:41', '2026-01-31 19:19:41'),
(2783, 'OCC', 'SECO', 'Francisco de Orellana Airport', NULL, 'EC', 'Orellana', -0.4628860, -76.9868000, 'active', '2026-01-31 19:19:42', '2026-01-31 19:19:42'),
(2784, 'TPN', 'SETI', 'Tiputini Airport', NULL, 'EC', 'Orellana', -0.7761110, -75.5264000, 'active', '2026-01-31 19:19:42', '2026-01-31 19:19:42'),
(2785, 'PTZ', 'SESM', 'Rio Amazonas Airport', NULL, 'EC', 'Pastaza', -1.5052400, -78.0627000, 'active', '2026-01-31 19:19:42', '2026-01-31 19:19:42'),
(2786, 'UIO', 'SEQM', 'Mariscal Sucre International Airport', NULL, 'EC', 'Pichincha', -0.1291670, -78.3575000, 'active', '2026-01-31 19:19:43', '2026-01-31 19:19:43'),
(2787, 'SNC', 'SESA', 'General Ulpiano Paez Airport', NULL, 'EC', 'Santa Elena', -2.2049900, -80.9889000, 'active', '2026-01-31 19:19:43', '2026-01-31 19:19:43'),
(2788, 'LGQ', 'SENL', 'Lago Agrio Airport', NULL, 'EC', 'Sucumbios', 0.0930560, -76.8675000, 'active', '2026-01-31 19:19:44', '2026-01-31 19:19:44'),
(2789, 'PYO', 'SEPT', 'Putumayo Airport', NULL, 'EC', 'Sucumbios', 0.1159490, -75.8502000, 'active', '2026-01-31 19:19:44', '2026-01-31 19:19:44'),
(2790, 'TPC', 'SETR', 'Tarapoa Airport', NULL, 'EC', 'Sucumbios', -0.1229560, -76.3378000, 'active', '2026-01-31 19:19:44', '2026-01-31 19:19:44'),
(2791, 'ATF', 'SEAM', 'Chachoan Airport', NULL, 'EC', 'Tungurahua', -1.2120700, -78.5746000, 'active', '2026-01-31 19:19:45', '2026-01-31 19:19:45'),
(2792, 'TLL', 'EETN', 'Tallinn Airport (Lennart Meri Tallinn Airport)', NULL, 'EE', 'Harjumaa', 59.4133000, 24.8328000, 'active', '2026-01-31 19:19:45', '2026-01-31 19:19:45'),
(2793, 'KDL', 'EEKA', 'Kardla Airport', NULL, 'EE', 'Hiiumaa', 58.9908000, 22.8307000, 'active', '2026-01-31 19:19:45', '2026-01-31 19:19:45'),
(2794, 'EPU', 'EEPU', 'Parnu Airport', NULL, 'EE', 'Parnumaa', 58.4190000, 24.4728000, 'active', '2026-01-31 19:19:46', '2026-01-31 19:19:46'),
(2795, 'URE', 'EEKE', 'Kuressaare Airport', NULL, 'EE', 'Saaremaa', 58.2299000, 22.5095000, 'active', '2026-01-31 19:19:46', '2026-01-31 19:19:46'),
(2796, 'TAY', 'EETU', 'Tartu Airport', NULL, 'EE', 'Tartumaa', 58.3075000, 26.6904000, 'active', '2026-01-31 19:19:46', '2026-01-31 19:19:46'),
(2797, 'HRG', 'HEGN', 'Hurghada International Airport', NULL, 'EG', 'Al Bahr al Ahmar', 27.1783000, 33.7994000, 'active', '2026-01-31 19:19:47', '2026-01-31 19:19:47'),
(2798, 'RMF', 'HEMA', 'Marsa Alam International Airport', NULL, 'EG', 'Al Bahr al Ahmar', 25.5571000, 34.5837000, 'active', '2026-01-31 19:19:47', '2026-01-31 19:19:47'),
(2799, 'ALY', 'HEAX', 'El Nouzha Airport', NULL, 'EG', 'Al Iskandariyah', 31.1839000, 29.9489000, 'active', '2026-01-31 19:19:47', '2026-01-31 19:19:47'),
(2800, 'HBE', 'HEBA', 'Borg El Arab Airport', NULL, 'EG', 'Al Iskandariyah', 30.9177000, 29.6964000, 'active', '2026-01-31 19:19:48', '2026-01-31 19:19:48'),
(2801, 'SPX', NULL, 'Sphinx International Airport', NULL, 'EG', 'Al Jizah', 30.1097000, 30.8944000, 'active', '2026-01-31 19:19:48', '2026-01-31 19:19:48'),
(2802, 'EMY', 'HE25', 'El Minya Airport', NULL, 'EG', 'Al Minya', 28.1013000, 30.7303000, 'active', '2026-01-31 19:19:48', '2026-01-31 19:19:48'),
(2803, 'CAI', 'HECA', 'Cairo International Airport', NULL, 'EG', 'Al Qahirah', 30.1219000, 31.4056000, 'active', '2026-01-31 19:19:49', '2026-01-31 19:19:49'),
(2804, 'LXR', 'HELX', 'Luxor International Airport', NULL, 'EG', 'Al Uqsur', 25.6710000, 32.7066000, 'active', '2026-01-31 19:19:49', '2026-01-31 19:19:49'),
(2805, 'DAK', 'HEDK', 'Dakhla Oasis Airport', NULL, 'EG', 'Al Wadi al Jadid', 25.4116000, 29.0031000, 'active', '2026-01-31 19:19:49', '2026-01-31 19:19:49'),
(2806, 'GSQ', 'HEOW', 'Sharq Al-Owainat Airport', NULL, 'EG', 'Al Wadi al Jadid', 22.5857000, 28.7166000, 'active', '2026-01-31 19:19:50', '2026-01-31 19:19:50'),
(2807, 'UVL', 'HEKG', 'El Kharga Airport', NULL, 'EG', 'Al Wadi al Jadid', 25.4736000, 30.5907000, 'active', '2026-01-31 19:19:50', '2026-01-31 19:19:50'),
(2808, 'TFR', NULL, 'Wadi al Jandali Airport', NULL, 'EG', 'Ash Sharqiyah', 30.3000000, 31.7500000, 'active', '2026-01-31 19:19:50', '2026-01-31 19:19:50'),
(2809, 'ABS', 'HEBL', 'Abu Simbel Airport', NULL, 'EG', 'Aswan', 22.3760000, 31.6117000, 'active', '2026-01-31 19:19:51', '2026-01-31 19:19:51'),
(2810, 'ASW', 'HESN', 'Aswan International Airport', NULL, 'EG', 'Aswan', 23.9644000, 32.8200000, 'active', '2026-01-31 19:19:51', '2026-01-31 19:19:51'),
(2811, 'ATZ', 'HEAT', 'Assiut Airport', NULL, 'EG', 'Asyut', 27.0465000, 31.0120000, 'active', '2026-01-31 19:19:51', '2026-01-31 19:19:51'),
(2812, 'PSD', 'HEPS', 'Port Said Airport', NULL, 'EG', 'Bur Sa\'id', 31.2794000, 32.2400000, 'active', '2026-01-31 19:19:52', '2026-01-31 19:19:52'),
(2813, 'AUE', NULL, 'Abu Rudeis Airport', NULL, 'EG', 'Janub Sina\'', 28.8990000, 33.2025000, 'active', '2026-01-31 19:19:52', '2026-01-31 19:19:52'),
(2814, 'ELT', 'HETR', 'El Tor Airport', NULL, 'EG', 'Janub Sina\'', 28.2090000, 33.6455000, 'active', '2026-01-31 19:19:52', '2026-01-31 19:19:52'),
(2815, 'SKV', 'HESC', 'St. Catherine International Airport', NULL, 'EG', 'Janub Sina\'', 28.6853000, 34.0625000, 'active', '2026-01-31 19:19:53', '2026-01-31 19:19:53'),
(2816, 'SSH', 'HESH', 'Sharm el-Sheikh International Airport', NULL, 'EG', 'Janub Sina\'', 27.9773000, 34.3950000, 'active', '2026-01-31 19:19:53', '2026-01-31 19:19:53'),
(2817, 'TCP', 'HETB', 'Taba International Airport', NULL, 'EG', 'Janub Sina\'', 29.5878000, 34.7781000, 'active', '2026-01-31 19:19:53', '2026-01-31 19:19:53'),
(2818, 'DBB', 'HEAL', 'Al Alamain International Airport', NULL, 'EG', 'Matruh', 30.9245000, 28.4614000, 'active', '2026-01-31 19:19:54', '2026-01-31 19:19:54'),
(2819, 'MUH', 'HEMM', 'Marsa Matruh International Airport', NULL, 'EG', 'Matruh', 31.3254000, 27.2217000, 'active', '2026-01-31 19:19:54', '2026-01-31 19:19:54'),
(2820, 'SEW', NULL, 'Siwa Oasis North Airport', NULL, 'EG', 'Matruh', 29.3455000, 25.5067000, 'active', '2026-01-31 19:19:54', '2026-01-31 19:19:54'),
(2821, 'SQK', NULL, 'Sidi Barrani Airport', NULL, 'EG', 'Matruh', 31.4666000, 25.8780000, 'active', '2026-01-31 19:19:55', '2026-01-31 19:19:55'),
(2822, 'AAC', 'HEAR', 'El Arish International Airport', NULL, 'EG', 'Shamal Sina\'', 31.0733000, 33.8358000, 'active', '2026-01-31 19:19:55', '2026-01-31 19:19:55'),
(2823, 'HMB', 'HEMK', 'Sohag International Airport', NULL, 'EG', 'Suhaj', 26.3428000, 31.7428000, 'active', '2026-01-31 19:19:56', '2026-01-31 19:19:56'),
(2824, 'ASM', 'HHAS', 'Asmara International Airport', NULL, 'ER', 'Al Awsat', 15.2919000, 38.9107000, 'active', '2026-01-31 19:19:56', '2026-01-31 19:19:56'),
(2825, 'ASA', 'HHSB', 'Assab International Airport', NULL, 'ER', 'Janubi al Bahri al Ahmar', 13.0718000, 42.6450000, 'active', '2026-01-31 19:19:56', '2026-01-31 19:19:56'),
(2826, 'TES', 'HHTS', 'Teseney Airport', NULL, 'ER', 'Qash-Barkah', 15.1043000, 36.6817000, 'active', '2026-01-31 19:19:57', '2026-01-31 19:19:57'),
(2827, 'MSW', 'HHMS', 'Massawa International Airport', NULL, 'ER', 'Shimali al Bahri al Ahmar', 15.6700000, 39.3701000, 'active', '2026-01-31 19:19:57', '2026-01-31 19:19:57'),
(2828, 'AGP', 'LEMG', 'Malaga Airport', NULL, 'ES', 'Andalucia', 36.6749000, -4.4991100, 'active', '2026-01-31 19:19:57', '2026-01-31 19:19:57'),
(2829, 'GRX', 'LEGR', 'Federico Garcia Lorca Airport (Granada Jaen Airport)', NULL, 'ES', 'Andalucia', 37.1887000, -3.7773600, 'active', '2026-01-31 19:19:58', '2026-01-31 19:19:58'),
(2830, 'LEI', 'LEAM', 'Almeria Airport', NULL, 'ES', 'Andalucia', 36.8439000, -2.3701000, 'active', '2026-01-31 19:19:58', '2026-01-31 19:19:58'),
(2831, 'ODB', 'LEBA', 'Cordoba Airport', NULL, 'ES', 'Andalucia', 37.8420000, -4.8488800, 'active', '2026-01-31 19:19:58', '2026-01-31 19:19:58'),
(2832, 'OZP', 'LEMO', 'Moron Air Base', NULL, 'ES', 'Andalucia', 37.1749000, -5.6159400, 'active', '2026-01-31 19:19:59', '2026-01-31 19:19:59'),
(2833, 'ROZ', 'LERT', 'Naval Station Rota', NULL, 'ES', 'Andalucia', 36.6452000, -6.3494600, 'active', '2026-01-31 19:19:59', '2026-01-31 19:19:59'),
(2834, 'SVQ', 'LEZL', 'Seville Airport', NULL, 'ES', 'Andalucia', 37.4180000, -5.8931100, 'active', '2026-01-31 19:19:59', '2026-01-31 19:19:59'),
(2835, 'XRY', 'LEJR', 'Jerez Airport (La Parra Airport)', NULL, 'ES', 'Andalucia', 36.7446000, -6.0601100, 'active', '2026-01-31 19:20:00', '2026-01-31 19:20:00'),
(2836, 'HSK', 'LEHC', 'Huesca-Pirineos Airport', NULL, 'ES', 'Aragon', 42.0761000, -0.3166670, 'active', '2026-01-31 19:20:00', '2026-01-31 19:20:00'),
(2837, 'TEV', 'LETL', 'Teruel Airport', NULL, 'ES', 'Aragon', 40.4030000, -1.2183000, 'active', '2026-01-31 19:20:00', '2026-01-31 19:20:00'),
(2838, 'ZAZ', 'LEZG', 'Zaragoza Airport', NULL, 'ES', 'Aragon', 41.6662000, -1.0415500, 'active', '2026-01-31 19:20:01', '2026-01-31 19:20:01'),
(2839, 'OVD', 'LEAS', 'Asturias Airport (Oviedo Airport)', NULL, 'ES', 'Asturias, Principado de', 43.5636000, -6.0346200, 'active', '2026-01-31 19:20:01', '2026-01-31 19:20:01'),
(2840, 'ACE', 'GCRR', 'Lanzarote Airport', NULL, 'ES', 'Canarias', 28.9455000, -13.6052000, 'active', '2026-01-31 19:20:01', '2026-01-31 19:20:01'),
(2841, 'FUE', 'GCFV', 'Fuerteventura Airport', NULL, 'ES', 'Canarias', 28.4527000, -13.8638000, 'active', '2026-01-31 19:20:02', '2026-01-31 19:20:02'),
(2842, 'GMZ', 'GCGM', 'La Gomera Airport', NULL, 'ES', 'Canarias', 28.0296000, -17.2146000, 'active', '2026-01-31 19:20:02', '2026-01-31 19:20:02'),
(2843, 'LPA', 'GCLP', 'Gran Canaria Airport', NULL, 'ES', 'Canarias', 27.9319000, -15.3866000, 'active', '2026-01-31 19:20:02', '2026-01-31 19:20:02'),
(2844, 'SPC', 'GCLA', 'La Palma Airport', NULL, 'ES', 'Canarias', 28.6265000, -17.7556000, 'active', '2026-01-31 19:20:03', '2026-01-31 19:20:03'),
(2845, 'TFN', 'GCXO', 'Tenerife North Airport', NULL, 'ES', 'Canarias', 28.4847000, -16.3439000, 'active', '2026-01-31 19:20:03', '2026-01-31 19:20:03'),
(2846, 'TFS', 'GCTS', 'Tenerife South Airport', NULL, 'ES', 'Canarias', 28.0460000, -16.5728000, 'active', '2026-01-31 19:20:04', '2026-01-31 19:20:04'),
(2847, 'VDE', 'GCHI', 'El Hierro Airport', NULL, 'ES', 'Canarias', 27.8148000, -17.8871000, 'active', '2026-01-31 19:20:04', '2026-01-31 19:20:04'),
(2848, 'SDR', 'LEXJ', 'Santander Airport', NULL, 'ES', 'Cantabria', 43.4271000, -3.8200100, 'active', '2026-01-31 19:20:04', '2026-01-31 19:20:04'),
(2849, 'CQM', 'LERL', 'Ciudad Real Central Airport', NULL, 'ES', 'Castilla y Leon', 38.8564000, -3.9700000, 'active', '2026-01-31 19:20:05', '2026-01-31 19:20:05'),
(2850, 'LEN', 'LELN', 'Leon Airport', NULL, 'ES', 'Castilla y Leon', 42.5890000, -5.6555600, 'active', '2026-01-31 19:20:05', '2026-01-31 19:20:05'),
(2851, 'RGS', 'LEBG', 'Burgos Airport', NULL, 'ES', 'Castilla y Leon', 42.3576000, -3.6207600, 'active', '2026-01-31 19:20:05', '2026-01-31 19:20:05'),
(2852, 'SLM', 'LESA', 'Salamanca Airport', NULL, 'ES', 'Castilla y Leon', 40.9521000, -5.5019900, 'active', '2026-01-31 19:20:06', '2026-01-31 19:20:06'),
(2853, 'VLL', 'LEVD', 'Valladolid Airport', NULL, 'ES', 'Castilla y Leon', 41.7061000, -4.8519400, 'active', '2026-01-31 19:20:06', '2026-01-31 19:20:06'),
(2854, 'ABC', 'LEAB', 'Albacete Airport', NULL, 'ES', 'Castilla-La Mancha', 38.9485000, -1.8635200, 'active', '2026-01-31 19:20:06', '2026-01-31 19:20:06'),
(2855, 'BCN', 'LEBL', 'Barcelona El Prat Airport', NULL, 'ES', 'Catalunya', 41.2971000, 2.0784600, 'active', '2026-01-31 19:20:07', '2026-01-31 19:20:07'),
(2856, 'GRO', 'LEGE', 'Girona-Costa Brava Airport', NULL, 'ES', 'Catalunya', 41.9010000, 2.7605500, 'active', '2026-01-31 19:20:07', '2026-01-31 19:20:07'),
(2857, 'ILD', 'LEDA', 'Lleida-Alguaire Airport', NULL, 'ES', 'Catalunya', 41.7282000, 0.5350230, 'active', '2026-01-31 19:20:07', '2026-01-31 19:20:07'),
(2858, 'LEU', 'LESU', 'Andorra–La Seu d\'Urgell Airport', NULL, 'ES', 'Catalunya', 42.3386000, 1.4091700, 'active', '2026-01-31 19:20:08', '2026-01-31 19:20:08'),
(2859, 'REU', 'LERS', 'Reus Airport', NULL, 'ES', 'Catalunya', 41.1474000, 1.1671700, 'active', '2026-01-31 19:20:08', '2026-01-31 19:20:08'),
(2860, 'BJZ', 'LEBZ', 'Badajoz Airport (Talavera la Real Air Base)', NULL, 'ES', 'Extremadura', 38.8913000, -6.8213300, 'active', '2026-01-31 19:20:08', '2026-01-31 19:20:08'),
(2861, 'LCG', 'LECO', 'A Coruna Airport', NULL, 'ES', 'Galicia', 43.3021000, -8.3772600, 'active', '2026-01-31 19:20:09', '2026-01-31 19:20:09'),
(2862, 'SCQ', 'LEST', 'Santiago de Compostela Airport', NULL, 'ES', 'Galicia', 42.8963000, -8.4151400, 'active', '2026-01-31 19:20:09', '2026-01-31 19:20:09'),
(2863, 'VGO', 'LEVX', 'Vigo-Peinador Airport', NULL, 'ES', 'Galicia', 42.2318000, -8.6267700, 'active', '2026-01-31 19:20:09', '2026-01-31 19:20:09'),
(2864, 'IBZ', 'LEIB', 'Ibiza Airport', NULL, 'ES', 'Illes Balears', 38.8729000, 1.3731200, 'active', '2026-01-31 19:20:10', '2026-01-31 19:20:10'),
(2865, 'MAH', 'LEMH', 'Menorca Airport (Mahon Airport)', NULL, 'ES', 'Illes Balears', 39.8626000, 4.2186500, 'active', '2026-01-31 19:20:10', '2026-01-31 19:20:10'),
(2866, 'PMI', 'LEPA', 'Palma de Mallorca Airport', NULL, 'ES', 'Illes Balears', 39.5517000, 2.7388100, 'active', '2026-01-31 19:20:10', '2026-01-31 19:20:10'),
(2867, 'RJL', 'LELO', 'Logrono-Agoncilo', NULL, 'ES', 'La Rioja', 42.4610000, -2.3222400, 'active', '2026-01-31 19:20:11', '2026-01-31 19:20:11'),
(2868, 'MAD', 'LEMD', 'Adolfo Suarez Madrid-Barajas Airport', NULL, 'ES', 'Madrid, Comunidad de', 40.4719000, -3.5626400, 'active', '2026-01-31 19:20:12', '2026-01-31 19:20:12'),
(2869, 'TOJ', 'LETO', 'Madrid-Torrejon Airport', NULL, 'ES', 'Madrid, Comunidad de', 40.4967000, -3.4458700, 'active', '2026-01-31 19:20:13', '2026-01-31 19:20:13'),
(2870, 'MLN', 'GEML', 'Melilla Airport', NULL, 'ES', 'Melilla', 35.2798000, -2.9562600, 'active', '2026-01-31 19:20:13', '2026-01-31 19:20:13'),
(2871, 'MJV', 'LELC', 'Murcia-San Javier Airport', NULL, 'ES', 'Murcia, Region de', 37.7750000, -0.8123890, 'active', '2026-01-31 19:20:14', '2026-01-31 19:20:14'),
(2872, 'RMU', 'LEMI', 'Region de Murcia International Airport', NULL, 'ES', 'Murcia, Region de', 37.8030000, -1.1250000, 'active', '2026-01-31 19:20:14', '2026-01-31 19:20:14'),
(2873, 'PNA', 'LEPP', 'Pamplona Airport', NULL, 'ES', 'Navarra, Comunidad Foral de', 42.7700000, -1.6463300, 'active', '2026-01-31 19:20:14', '2026-01-31 19:20:14'),
(2874, 'BIO', 'LEBB', 'Bilbao Airport', NULL, 'ES', 'Pais Vasco', 43.3011000, -2.9106100, 'active', '2026-01-31 19:20:15', '2026-01-31 19:20:15'),
(2875, 'EAS', 'LESO', 'San Sebastian Airport', NULL, 'ES', 'Pais Vasco', 43.3565000, -1.7906100, 'active', '2026-01-31 19:20:15', '2026-01-31 19:20:15'),
(2876, 'VIT', 'LEVT', 'Vitoria Airport', NULL, 'ES', 'Pais Vasco', 42.8828000, -2.7244700, 'active', '2026-01-31 19:20:15', '2026-01-31 19:20:15'),
(2877, 'ALC', 'LEAL', 'Alicante-Elche Airport', NULL, 'ES', 'Valenciana, Comunidad', 38.2822000, -0.5581560, 'active', '2026-01-31 19:20:16', '2026-01-31 19:20:16'),
(2878, 'CDT', 'LECH', 'Castellon-Costa Azahar Airport', NULL, 'ES', 'Valenciana, Comunidad', 40.2139000, 0.0733330, 'active', '2026-01-31 19:20:16', '2026-01-31 19:20:16'),
(2879, 'VLC', 'LEVC', 'Valencia Airport', NULL, 'ES', 'Valenciana, Comunidad', 39.4893000, -0.4816250, 'active', '2026-01-31 19:20:16', '2026-01-31 19:20:16'),
(2880, 'ADD', 'HAAB', 'Addis Ababa Bole International Airport', NULL, 'ET', 'Addis Ababa', 8.9777800, 38.7994000, 'active', '2026-01-31 19:20:17', '2026-01-31 19:20:17'),
(2881, 'SZE', 'HASM', 'Semera Airport', NULL, 'ET', 'Afar', 11.7875000, 40.9915000, 'active', '2026-01-31 19:20:17', '2026-01-31 19:20:17'),
(2882, 'BJR', 'HABD', 'Bahir Dar Airport', NULL, 'ET', 'Amara', 11.6081000, 37.3216000, 'active', '2026-01-31 19:20:17', '2026-01-31 19:20:17'),
(2883, 'DBM', 'HADM', 'Debre Marqos Airport', NULL, 'ET', 'Amara', 10.3500000, 37.7170000, 'active', '2026-01-31 19:20:18', '2026-01-31 19:20:18'),
(2884, 'DBT', 'HADT', 'Debre Tabor Airport', NULL, 'ET', 'Amara', 11.9670000, 38.0000000, 'active', '2026-01-31 19:20:18', '2026-01-31 19:20:18'),
(2885, 'DSE', 'HADC', 'Combolcha Airport', NULL, 'ET', 'Amara', 11.0825000, 39.7114000, 'active', '2026-01-31 19:20:18', '2026-01-31 19:20:18'),
(2886, 'ETE', 'HAMM', 'Genda Wuha Airport', NULL, 'ET', 'Amara', 12.9330000, 36.1670000, 'active', '2026-01-31 19:20:19', '2026-01-31 19:20:19'),
(2887, 'GDQ', 'HAGN', 'Gondar Airport (Atse Tewodros Airport)', NULL, 'ET', 'Amara', 12.5199000, 37.4340000, 'active', '2026-01-31 19:20:19', '2026-01-31 19:20:19'),
(2888, 'LLI', 'HALL', 'Lalibela Airport', NULL, 'ET', 'Amara', 11.9750000, 38.9800000, 'active', '2026-01-31 19:20:20', '2026-01-31 19:20:20'),
(2889, 'MKS', 'HAMA', 'Mekane Selam Airport', NULL, 'ET', 'Amara', 10.7254000, 38.7415000, 'active', '2026-01-31 19:20:20', '2026-01-31 19:20:20'),
(2890, 'OTA', NULL, 'Mota Airport', NULL, 'ET', 'Amara', 11.0830000, 37.8670000, 'active', '2026-01-31 19:20:20', '2026-01-31 19:20:20'),
(2891, 'PWI', 'HAPW', 'Beles Airport', NULL, 'ET', 'Amara', 11.3126000, 36.4164000, 'active', '2026-01-31 19:20:21', '2026-01-31 19:20:21'),
(2892, 'ASO', 'HASO', 'Asosa Airport', NULL, 'ET', 'Binshangul Gumuz', 10.0185000, 34.5863000, 'active', '2026-01-31 19:20:21', '2026-01-31 19:20:21'),
(2893, 'DIR', 'HADR', 'Aba Tenna Dejazmach Yilma International Airport', NULL, 'ET', 'Dire Dawa', 9.6247000, 41.8542000, 'active', '2026-01-31 19:20:21', '2026-01-31 19:20:21'),
(2894, 'GMB', 'HAGM', 'Gambela Airport', NULL, 'ET', 'Gambela Hizboch', 8.1287600, 34.5631000, 'active', '2026-01-31 19:20:22', '2026-01-31 19:20:22'),
(2895, 'ALK', NULL, 'Asella Airport', NULL, 'ET', 'Oromiya', 7.9621300, 39.1283000, 'active', '2026-01-31 19:20:22', '2026-01-31 19:20:22'),
(2896, 'BEI', 'HABE', 'Beica Airport', NULL, 'ET', 'Oromiya', 9.3863900, 34.5219000, 'active', '2026-01-31 19:20:22', '2026-01-31 19:20:22'),
(2897, 'DEM', 'HADD', 'Dembidolo Airport', NULL, 'ET', 'Oromiya', 8.5540000, 34.8580000, 'active', '2026-01-31 19:20:23', '2026-01-31 19:20:23'),
(2898, 'EGL', 'HANG', 'Neghelle Airport', NULL, 'ET', 'Oromiya', 5.2897000, 39.7023000, 'active', '2026-01-31 19:20:23', '2026-01-31 19:20:23'),
(2899, 'FNH', 'HAFN', 'Fincha Airport', NULL, 'ET', 'Oromiya', 9.5830000, 37.3500000, 'active', '2026-01-31 19:20:23', '2026-01-31 19:20:23'),
(2900, 'GNN', 'HAGH', 'Ginir Airport', NULL, 'ET', 'Oromiya', 7.1500000, 40.7170000, 'active', '2026-01-31 19:20:24', '2026-01-31 19:20:24'),
(2901, 'GOB', 'HAGB', 'Robe Airport', NULL, 'ET', 'Oromiya', 7.1160600, 40.0463000, 'active', '2026-01-31 19:20:24', '2026-01-31 19:20:24'),
(2902, 'GOR', 'HAGR', 'Gore Airport', NULL, 'ET', 'Oromiya', 8.1614000, 35.5529000, 'active', '2026-01-31 19:20:24', '2026-01-31 19:20:24'),
(2903, 'JIM', 'HAJM', 'Aba Segud Airport', NULL, 'ET', 'Oromiya', 7.6660900, 36.8166000, 'active', '2026-01-31 19:20:25', '2026-01-31 19:20:25'),
(2904, 'MZX', 'HAML', 'Mena Airport', NULL, 'ET', 'Oromiya', 6.3500000, 39.7167000, 'active', '2026-01-31 19:20:25', '2026-01-31 19:20:25'),
(2905, 'NDM', 'HAMN', 'Mendi Airport', NULL, 'ET', 'Oromiya', 9.7670000, 35.1000000, 'active', '2026-01-31 19:20:25', '2026-01-31 19:20:25'),
(2906, 'NEJ', 'HANJ', 'Nejjo Airport', NULL, 'ET', 'Oromiya', 9.5500000, 35.4670000, 'active', '2026-01-31 19:20:26', '2026-01-31 19:20:26'),
(2907, 'NEK', 'HANK', 'Nekemte Airport', NULL, 'ET', 'Oromiya', 9.0500000, 36.6000000, 'active', '2026-01-31 19:20:26', '2026-01-31 19:20:26'),
(2908, 'SKR', 'HASK', 'Shakiso Airport', NULL, 'ET', 'Oromiya', 5.6923000, 38.9764000, 'active', '2026-01-31 19:20:26', '2026-01-31 19:20:26'),
(2909, 'XBL', 'HABB', 'Bedele Airport (Buno Bedele Airport)', NULL, 'ET', 'Oromiya', 8.4560000, 36.3520000, 'active', '2026-01-31 19:20:27', '2026-01-31 19:20:27'),
(2910, 'ABK', 'HAKD', 'Kabri Dar Airport', NULL, 'ET', 'Sumale', 6.7340000, 44.2530000, 'active', '2026-01-31 19:20:27', '2026-01-31 19:20:27');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(2911, 'DGC', NULL, 'Degeh Bur Airport', NULL, 'ET', 'Sumale', 8.2340000, 43.5673000, 'active', '2026-01-31 19:20:27', '2026-01-31 19:20:27'),
(2912, 'GDE', 'HAGO', 'Gode Airport', NULL, 'ET', 'Sumale', 5.9351300, 43.5786000, 'active', '2026-01-31 19:20:28', '2026-01-31 19:20:28'),
(2913, 'GLC', NULL, 'Geladi Airport', NULL, 'ET', 'Sumale', 6.9844400, 46.4214000, 'active', '2026-01-31 19:20:28', '2026-01-31 19:20:28'),
(2914, 'HIL', 'HASL', 'Shilavo Airport', NULL, 'ET', 'Sumale', 6.0833300, 44.7667000, 'active', '2026-01-31 19:20:28', '2026-01-31 19:20:28'),
(2915, 'JIJ', 'HAJJ', 'Wilwal International Airport', NULL, 'ET', 'Sumale', 9.3325000, 42.9121000, 'active', '2026-01-31 19:20:29', '2026-01-31 19:20:29'),
(2916, 'LFO', 'HAKL', 'Kelafo Airport', NULL, 'ET', 'Sumale', 5.6570000, 44.3500000, 'active', '2026-01-31 19:20:29', '2026-01-31 19:20:29'),
(2917, 'WRA', 'HAWR', 'Warder Airport', NULL, 'ET', 'Sumale', 6.9724000, 45.3334000, 'active', '2026-01-31 19:20:29', '2026-01-31 19:20:29'),
(2918, 'AXU', 'HAAX', 'Axum Airport', NULL, 'ET', 'Tigray', 14.1468000, 38.7728000, 'active', '2026-01-31 19:20:30', '2026-01-31 19:20:30'),
(2919, 'HUE', 'HAHU', 'Humera Airport', NULL, 'ET', 'Tigray', 14.2500000, 36.5830000, 'active', '2026-01-31 19:20:30', '2026-01-31 19:20:30'),
(2920, 'MQX', 'HAMK', 'Alula Aba Nega Airport', NULL, 'ET', 'Tigray', 13.4674000, 39.5335000, 'active', '2026-01-31 19:20:30', '2026-01-31 19:20:30'),
(2921, 'SHC', NULL, 'Shire Airport', NULL, 'ET', 'Tigray', 14.0781000, 38.2725000, 'active', '2026-01-31 19:20:31', '2026-01-31 19:20:31'),
(2922, 'AMH', 'HAAM', 'Arba Minch Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 6.0393900, 37.5905000, 'active', '2026-01-31 19:20:31', '2026-01-31 19:20:31'),
(2923, 'AWA', 'HALA', 'Awasa Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 7.0670000, 38.5000000, 'active', '2026-01-31 19:20:31', '2026-01-31 19:20:31'),
(2924, 'BCO', 'HABC', 'Baco Airport (Jinka Airport)', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 5.7828700, 36.5620000, 'active', '2026-01-31 19:20:32', '2026-01-31 19:20:32'),
(2925, 'BCY', 'HABU', 'Bulchi Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 6.2166700, 36.6667000, 'active', '2026-01-31 19:20:32', '2026-01-31 19:20:32'),
(2926, 'MTF', 'HAMT', 'Mizan Teferi Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 6.9571000, 35.5547000, 'active', '2026-01-31 19:20:32', '2026-01-31 19:20:32'),
(2927, 'MUJ', 'HAMR', 'Mui Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 5.8646000, 35.7485000, 'active', '2026-01-31 19:20:33', '2026-01-31 19:20:33'),
(2928, 'SXU', 'HASD', 'Soddu Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 6.8170000, 37.7500000, 'active', '2026-01-31 19:20:33', '2026-01-31 19:20:33'),
(2929, 'TIE', 'HATP', 'Tippi Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 7.2024000, 35.4150000, 'active', '2026-01-31 19:20:33', '2026-01-31 19:20:33'),
(2930, 'TUJ', 'HAMJ', 'Tum Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 6.2600000, 35.5184000, 'active', '2026-01-31 19:20:34', '2026-01-31 19:20:34'),
(2931, 'WAC', 'HAWC', 'Wacca Airport', NULL, 'ET', 'YeDebub Biheroch Bihereseboch na Hizboch', 7.1670000, 37.1670000, 'active', '2026-01-31 19:20:34', '2026-01-31 19:20:34'),
(2932, 'LPP', 'EFLP', 'Lappeenranta Airport', NULL, 'FI', 'Etela-Karjala', 61.0446000, 28.1447000, 'active', '2026-01-31 19:20:34', '2026-01-31 19:20:34'),
(2933, 'KAU', 'EFKA', 'Kauhava Airfield', NULL, 'FI', 'Etela-Pohjanmaa', 63.1271000, 23.0514000, 'active', '2026-01-31 19:20:35', '2026-01-31 19:20:35'),
(2934, 'KHJ', 'EFKJ', 'Kauhajoki Airfield', NULL, 'FI', 'Etela-Pohjanmaa', 62.4625000, 22.3931000, 'active', '2026-01-31 19:20:35', '2026-01-31 19:20:35'),
(2935, 'SJY', 'EFSI', 'Seinajoki Airport', NULL, 'FI', 'Etela-Pohjanmaa', 62.6921000, 22.8323000, 'active', '2026-01-31 19:20:35', '2026-01-31 19:20:35'),
(2936, 'MIK', 'EFMI', 'Mikkeli Airport', NULL, 'FI', 'Etela-Savo', 61.6866000, 27.2018000, 'active', '2026-01-31 19:20:36', '2026-01-31 19:20:36'),
(2937, 'SVL', 'EFSA', 'Savonlinna Airport', NULL, 'FI', 'Etela-Savo', 61.9431000, 28.9451000, 'active', '2026-01-31 19:20:36', '2026-01-31 19:20:36'),
(2938, 'VRK', 'EFVR', 'Varkaus Airport', NULL, 'FI', 'Etela-Savo', 62.1711000, 27.8686000, 'active', '2026-01-31 19:20:36', '2026-01-31 19:20:36'),
(2939, 'KAJ', 'EFKI', 'Kajaani Airport', NULL, 'FI', 'Kainuu', 64.2855000, 27.6924000, 'active', '2026-01-31 19:20:37', '2026-01-31 19:20:37'),
(2940, 'JYV', 'EFJY', 'Jyvaskyla Airport', NULL, 'FI', 'Keski-Suomi', 62.3995000, 25.6783000, 'active', '2026-01-31 19:20:37', '2026-01-31 19:20:37'),
(2941, 'KEV', 'EFHA', 'Halli Airport', NULL, 'FI', 'Keski-Suomi', 61.8560000, 24.7867000, 'active', '2026-01-31 19:20:37', '2026-01-31 19:20:37'),
(2942, 'UTI', 'EFUT', 'Utti Airport', NULL, 'FI', 'Kymenlaakso', 60.8964000, 26.9384000, 'active', '2026-01-31 19:20:38', '2026-01-31 19:20:38'),
(2943, 'ENF', 'EFET', 'Enontekio Airport', NULL, 'FI', 'Lappi', 68.3626000, 23.4243000, 'active', '2026-01-31 19:20:38', '2026-01-31 19:20:38'),
(2944, 'IVL', 'EFIV', 'Ivalo Airport', NULL, 'FI', 'Lappi', 68.6073000, 27.4053000, 'active', '2026-01-31 19:20:38', '2026-01-31 19:20:38'),
(2945, 'KEM', 'EFKE', 'Kemi-Tornio Airport', NULL, 'FI', 'Lappi', 65.7787000, 24.5821000, 'active', '2026-01-31 19:20:39', '2026-01-31 19:20:39'),
(2946, 'KTT', 'EFKT', 'Kittila Airport', NULL, 'FI', 'Lappi', 67.7010000, 24.8468000, 'active', '2026-01-31 19:20:39', '2026-01-31 19:20:39'),
(2947, 'RVN', 'EFRO', 'Rovaniemi Airport', NULL, 'FI', 'Lappi', 66.5648000, 25.8304000, 'active', '2026-01-31 19:20:40', '2026-01-31 19:20:40'),
(2948, 'SOT', 'EFSO', 'Sodankyla Airfield', NULL, 'FI', 'Lappi', 67.3950000, 26.6191000, 'active', '2026-01-31 19:20:40', '2026-01-31 19:20:40'),
(2949, 'TMP', 'EFTP', 'Tampere-Pirkkala Airport', NULL, 'FI', 'Pirkanmaa', 61.4141000, 23.6044000, 'active', '2026-01-31 19:20:40', '2026-01-31 19:20:40'),
(2950, 'KOK', 'EFKK', 'Kokkola-Pietarsaari Airport', NULL, 'FI', 'Pohjanmaa', 63.7212000, 23.1431000, 'active', '2026-01-31 19:20:41', '2026-01-31 19:20:41'),
(2951, 'VAA', 'EFVA', 'Vaasa Airport', NULL, 'FI', 'Pohjanmaa', 63.0507000, 21.7622000, 'active', '2026-01-31 19:20:41', '2026-01-31 19:20:41'),
(2952, 'JOE', 'EFJO', 'Joensuu Airport', NULL, 'FI', 'Pohjois-Karjala', 62.6629000, 29.6075000, 'active', '2026-01-31 19:20:41', '2026-01-31 19:20:41'),
(2953, 'KTQ', 'EFIT', 'Kitee Airfield', NULL, 'FI', 'Pohjois-Karjala', 62.1661000, 30.0736000, 'active', '2026-01-31 19:20:42', '2026-01-31 19:20:42'),
(2954, 'KAO', 'EFKS', 'Kuusamo Airport', NULL, 'FI', 'Pohjois-Pohjanmaa', 65.9876000, 29.2394000, 'active', '2026-01-31 19:20:42', '2026-01-31 19:20:42'),
(2955, 'OUL', 'EFOU', 'Oulu Airport', NULL, 'FI', 'Pohjois-Pohjanmaa', 64.9301000, 25.3546000, 'active', '2026-01-31 19:20:42', '2026-01-31 19:20:42'),
(2956, 'YLI', 'EFYL', 'Ylivieska Airfield', NULL, 'FI', 'Pohjois-Pohjanmaa', 64.0547000, 24.7253000, 'active', '2026-01-31 19:20:43', '2026-01-31 19:20:43'),
(2957, 'KUO', 'EFKU', 'Kuopio Airport', NULL, 'FI', 'Pohjois-Savo', 63.0071000, 27.7978000, 'active', '2026-01-31 19:20:43', '2026-01-31 19:20:43'),
(2958, 'POR', 'EFPO', 'Pori Airport', NULL, 'FI', 'Satakunta', 61.4617000, 21.8000000, 'active', '2026-01-31 19:20:43', '2026-01-31 19:20:43'),
(2959, 'HEL', 'EFHK', 'Helsinki Airport (Helsinki-Vantaa Airport)', NULL, 'FI', 'Uusimaa', 60.3172000, 24.9633000, 'active', '2026-01-31 19:20:44', '2026-01-31 19:20:44'),
(2960, 'HEM', 'EFHF', 'Helsinki-Malmi Airport', NULL, 'FI', 'Uusimaa', 60.2546000, 25.0428000, 'active', '2026-01-31 19:20:44', '2026-01-31 19:20:44'),
(2961, 'HYV', 'EFHV', 'Hyvink- Airfield', NULL, 'FI', 'Uusimaa', 60.6544000, 24.8811000, 'active', '2026-01-31 19:20:44', '2026-01-31 19:20:44'),
(2962, 'MHQ', 'EFMA', 'Mariehamn Airport', NULL, 'FI', 'Varsinais-Suomi', 60.1222000, 19.8982000, 'active', '2026-01-31 19:20:45', '2026-01-31 19:20:45'),
(2963, 'TKU', 'EFTU', 'Turku Airport', NULL, 'FI', 'Varsinais-Suomi', 60.5141000, 22.2628000, 'active', '2026-01-31 19:20:45', '2026-01-31 19:20:45'),
(2964, 'LUC', 'NFNH', 'Laucala Airport', NULL, 'FJ', 'Central', -16.7481000, -179.6670000, 'active', '2026-01-31 19:20:45', '2026-01-31 19:20:45'),
(2965, 'NAN', 'NFFN', 'Nadi International Airport', NULL, 'FJ', 'Central', -17.7554000, 177.4430000, 'active', '2026-01-31 19:20:46', '2026-01-31 19:20:46'),
(2966, 'PHR', 'NFND', 'Pacific Harbour Airport', NULL, 'FJ', 'Central', -18.2570000, 178.0680000, 'active', '2026-01-31 19:20:46', '2026-01-31 19:20:46'),
(2967, 'SUV', 'NFNA', 'Nausori International Airport', NULL, 'FJ', 'Central', -18.0433000, 178.5590000, 'active', '2026-01-31 19:20:46', '2026-01-31 19:20:46'),
(2968, 'ICI', 'NFCI', 'Cicia Airport', NULL, 'FJ', 'Eastern', -17.7433000, -179.3420000, 'active', '2026-01-31 19:20:47', '2026-01-31 19:20:47'),
(2969, 'KAY', 'NFNW', 'Wakaya Airport', NULL, 'FJ', 'Eastern', -17.6170000, 179.0170000, 'active', '2026-01-31 19:20:47', '2026-01-31 19:20:47'),
(2970, 'KDV', 'NFKD', 'Vunisea Airport', NULL, 'FJ', 'Eastern', -19.0581000, 178.1570000, 'active', '2026-01-31 19:20:47', '2026-01-31 19:20:47'),
(2971, 'KXF', 'NFNO', 'Koro Airport', NULL, 'FJ', 'Eastern', -17.3458000, 179.4220000, 'active', '2026-01-31 19:20:48', '2026-01-31 19:20:48'),
(2972, 'LEV', 'NFNB', 'Levuka Airfield (Bureta Airport)', NULL, 'FJ', 'Eastern', -17.7111000, 178.7590000, 'active', '2026-01-31 19:20:48', '2026-01-31 19:20:48'),
(2973, 'LKB', 'NFNK', 'Lakeba Airport', NULL, 'FJ', 'Eastern', -18.1992000, -178.8170000, 'active', '2026-01-31 19:20:48', '2026-01-31 19:20:48'),
(2974, 'MFJ', 'NFMO', 'Moala Airport', NULL, 'FJ', 'Eastern', -18.5667000, 179.9510000, 'active', '2026-01-31 19:20:49', '2026-01-31 19:20:49'),
(2975, 'NGI', 'NFNG', 'Gau Airport', NULL, 'FJ', 'Eastern', -18.1156000, 179.3400000, 'active', '2026-01-31 19:20:49', '2026-01-31 19:20:49'),
(2976, 'ONU', 'NFOL', 'Ono-i-Lau Airport', NULL, 'FJ', 'Eastern', -20.6589000, -178.7410000, 'active', '2026-01-31 19:20:50', '2026-01-31 19:20:50'),
(2977, 'VBV', 'NFVB', 'Vanuabalavu Airport', NULL, 'FJ', 'Eastern', -17.2690000, -178.9760000, 'active', '2026-01-31 19:20:50', '2026-01-31 19:20:50'),
(2978, 'AQS', NULL, 'Saqani Airport', NULL, 'FJ', 'Northern', -16.4494000, 179.7400000, 'active', '2026-01-31 19:20:51', '2026-01-31 19:20:51'),
(2979, 'BVF', 'NFNU', 'Dama Airport', NULL, 'FJ', 'Northern', -16.8598000, 178.6230000, 'active', '2026-01-31 19:20:51', '2026-01-31 19:20:51'),
(2980, 'LBS', 'NFNL', 'Labasa Airport', NULL, 'FJ', 'Northern', -16.4667000, 179.3400000, 'active', '2026-01-31 19:20:51', '2026-01-31 19:20:51'),
(2981, 'RBI', 'NFFR', 'Rabi Airport', NULL, 'FJ', 'Northern', -16.5337000, 179.9760000, 'active', '2026-01-31 19:20:52', '2026-01-31 19:20:52'),
(2982, 'RTA', 'NFNR', 'Rotuma Airport', NULL, 'FJ', 'Northern', -12.4825000, 177.0710000, 'active', '2026-01-31 19:20:52', '2026-01-31 19:20:52'),
(2983, 'SVU', 'NFNS', 'Savusavu Airport', NULL, 'FJ', 'Northern', -16.8028000, 179.3410000, 'active', '2026-01-31 19:20:52', '2026-01-31 19:20:52'),
(2984, 'TVU', 'NFNM', 'Matei Airport', NULL, 'FJ', 'Northern', -16.6906000, -179.8770000, 'active', '2026-01-31 19:20:53', '2026-01-31 19:20:53'),
(2985, 'BXL', NULL, 'Blue Lagoon Seaplane Base', NULL, 'FJ', 'Western', -16.9430000, 177.3680000, 'active', '2026-01-31 19:20:53', '2026-01-31 19:20:53'),
(2986, 'CST', 'NFCS', 'Castaway Island Seaplane Base', NULL, 'FJ', 'Western', -17.7358000, 177.1290000, 'active', '2026-01-31 19:20:53', '2026-01-31 19:20:53'),
(2987, 'KVU', NULL, 'Korolevu Seaplane Base', NULL, 'FJ', 'Western', -17.7543000, 177.4370000, 'active', '2026-01-31 19:20:54', '2026-01-31 19:20:54'),
(2988, 'MNF', 'NFMA', 'Mana Island Airport', NULL, 'FJ', 'Western', -17.6731000, 177.0980000, 'active', '2026-01-31 19:20:54', '2026-01-31 19:20:54'),
(2989, 'NTA', NULL, 'Natadola Seaplane Base', NULL, 'FJ', 'Western', -18.0677000, 177.3150000, 'active', '2026-01-31 19:20:54', '2026-01-31 19:20:54'),
(2990, 'PTF', 'NFFO', 'Malolo Lailai Airport', NULL, 'FJ', 'Western', -17.7779000, 177.1970000, 'active', '2026-01-31 19:20:55', '2026-01-31 19:20:55'),
(2991, 'TTL', NULL, 'Turtle Island Seaplane Base', NULL, 'FJ', 'Western', -16.9660000, 177.3680000, 'active', '2026-01-31 19:20:55', '2026-01-31 19:20:55'),
(2992, 'VAU', 'NFNV', 'Vatukoula Airport', NULL, 'FJ', 'Western', -17.5000000, 177.8420000, 'active', '2026-01-31 19:20:55', '2026-01-31 19:20:55'),
(2993, 'VTF', 'NFVL', 'Vatulele Airport', NULL, 'FJ', 'Western', -18.5125000, 177.6390000, 'active', '2026-01-31 19:20:56', '2026-01-31 19:20:56'),
(2994, 'YAS', 'NFSW', 'Yasawa Island Airport', NULL, 'FJ', 'Western', -16.7589000, 177.5450000, 'active', '2026-01-31 19:20:56', '2026-01-31 19:20:56'),
(2995, 'FAE', 'EKVG', 'Vagar Airport', NULL, 'FK', 'Falkland Islands (Malvinas)', 62.0636000, -7.2772200, 'active', '2026-01-31 19:20:56', '2026-01-31 19:20:56'),
(2996, 'MPN', 'EGYP', 'RAF Mount Pleasant', NULL, 'FK', 'Falkland Islands (Malvinas)', -51.8228000, -58.4472000, 'active', '2026-01-31 19:20:57', '2026-01-31 19:20:57'),
(2997, 'PSY', 'SFAL', 'Port Stanley Airport', NULL, 'FK', 'Falkland Islands (Malvinas)', -51.6857000, -57.7776000, 'active', '2026-01-31 19:20:57', '2026-01-31 19:20:57'),
(2998, 'TKK', 'PTKK', 'Chuuk International Airport', NULL, 'FM', 'Chuuk', 7.4618700, 151.8430000, 'active', '2026-01-31 19:20:57', '2026-01-31 19:20:57'),
(2999, 'KSA', 'PTSA', 'Kosrae International Airport', NULL, 'FM', 'Kosrae', 5.3569800, 162.9580000, 'active', '2026-01-31 19:20:58', '2026-01-31 19:20:58'),
(3000, 'PNI', 'PTPN', 'Pohnpei International Airport', NULL, 'FM', 'Pohnpei', 6.9851000, 158.2090000, 'active', '2026-01-31 19:20:58', '2026-01-31 19:20:58'),
(3001, 'ULI', NULL, 'Ulithi Airport (FAA: TT02)', NULL, 'FM', 'Yap', 10.0198000, 139.7900000, 'active', '2026-01-31 19:20:59', '2026-01-31 19:20:59'),
(3002, 'YAP', 'PTYA', 'Yap International Airport', NULL, 'FM', 'Yap', 9.4989100, 138.0830000, 'active', '2026-01-31 19:21:00', '2026-01-31 19:21:00'),
(3003, 'AHZ', 'LFHU', 'Alpe d\'Huez Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.0883000, 6.0847200, 'active', '2026-01-31 19:21:00', '2026-01-31 19:21:00'),
(3004, 'AUR', 'LFLW', 'Aurillac - Tronquieres Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 44.8914000, 2.4219400, 'active', '2026-01-31 19:21:00', '2026-01-31 19:21:00'),
(3005, 'CFE', 'LFLC', 'Clermont-Ferrand Auvergne Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.7867000, 3.1691700, 'active', '2026-01-31 19:21:01', '2026-01-31 19:21:01'),
(3006, 'CMF', 'LFLB', 'Chambery-Savoie Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.6381000, 5.8802300, 'active', '2026-01-31 19:21:01', '2026-01-31 19:21:01'),
(3007, 'CVF', 'LFLJ', 'Courchevel Altiport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.3967000, 6.6347200, 'active', '2026-01-31 19:21:01', '2026-01-31 19:21:01'),
(3008, 'EBU', 'LFMH', 'Saint-Etienne-Boutheon Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.5406000, 4.2963900, 'active', '2026-01-31 19:21:02', '2026-01-31 19:21:02'),
(3009, 'GNB', 'LFLS', 'Grenoble-Isere Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.3629000, 5.3293700, 'active', '2026-01-31 19:21:02', '2026-01-31 19:21:02'),
(3010, 'LPY', 'LFHP', 'Le Puy - Loudes Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.0807000, 3.7628900, 'active', '2026-01-31 19:21:02', '2026-01-31 19:21:02'),
(3011, 'LYN', 'LFLY', 'Lyon-Bron Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.7272000, 4.9442700, 'active', '2026-01-31 19:21:03', '2026-01-31 19:21:03'),
(3012, 'LYS', 'LFLL', 'Lyon-Saint-Exupery Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.7256000, 5.0811100, 'active', '2026-01-31 19:21:03', '2026-01-31 19:21:03'),
(3013, 'MCU', 'LFBK', 'Montlucon - Gueret Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 46.2226000, 2.3639600, 'active', '2026-01-31 19:21:03', '2026-01-31 19:21:03'),
(3014, 'MFX', 'LFKX', 'Meribel Altiport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.4070000, 6.5779400, 'active', '2026-01-31 19:21:04', '2026-01-31 19:21:04'),
(3015, 'MVV', 'LFHM', 'Megeve Altiport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.8208000, 6.6522200, 'active', '2026-01-31 19:21:04', '2026-01-31 19:21:04'),
(3016, 'NCY', 'LFLP', 'Annecy - Haute-Savoie - Mont Blanc Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 45.9308000, 6.1063900, 'active', '2026-01-31 19:21:04', '2026-01-31 19:21:04'),
(3017, 'OBS', 'LFHO', 'Aubenas Aerodrome (Arddecheche Meridionale Aerodrom)', NULL, 'FR', 'Auvergne-Rhone-Alpes', 44.5442000, 4.3721900, 'active', '2026-01-31 19:21:05', '2026-01-31 19:21:05'),
(3018, 'RNE', 'LFLO', 'Roanne Renaison Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 46.0583000, 4.0013900, 'active', '2026-01-31 19:21:05', '2026-01-31 19:21:05'),
(3019, 'VAF', 'LFLU', 'Valence-Chabeuil Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 44.9216000, 4.9699000, 'active', '2026-01-31 19:21:05', '2026-01-31 19:21:05'),
(3020, 'VHY', 'LFLV', 'Vichy - Charmeil Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 46.1697000, 3.4037400, 'active', '2026-01-31 19:21:06', '2026-01-31 19:21:06'),
(3021, 'XBK', 'LFHS', 'Bourg – Ceyzériat Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 46.2056000, 5.2916700, 'active', '2026-01-31 19:21:06', '2026-01-31 19:21:06'),
(3022, 'XMU', 'LFHY', 'Moulins – Montbeugny Airport', NULL, 'FR', 'Auvergne-Rhone-Alpes', 46.5344000, 3.4216700, 'active', '2026-01-31 19:21:06', '2026-01-31 19:21:06'),
(3023, 'AUF', 'LFLA', 'Auxerre - Branches Aerodrome', NULL, 'FR', 'Bourgogne-Franche-Comte', 47.8502000, 3.4971100, 'active', '2026-01-31 19:21:07', '2026-01-31 19:21:07'),
(3024, 'DIJ', 'LFSD', 'Dijon Air Base', NULL, 'FR', 'Bourgogne-Franche-Comte', 47.2689000, 5.0900000, 'active', '2026-01-31 19:21:07', '2026-01-31 19:21:07'),
(3025, 'DLE', 'LFGJ', 'Dole-Jura Airport', NULL, 'FR', 'Bourgogne-Franche-Comte', 47.0427000, 5.4350600, 'active', '2026-01-31 19:21:07', '2026-01-31 19:21:07'),
(3026, 'NVS', 'LFQG', 'Nevers - Fourchambault Airport', NULL, 'FR', 'Bourgogne-Franche-Comte', 47.0026000, 3.1133300, 'active', '2026-01-31 19:21:08', '2026-01-31 19:21:08'),
(3027, 'SYT', 'LFLN', 'Saint-Yan Airport (Charolais Bourgogne Sud Airport)', NULL, 'FR', 'Bourgogne-Franche-Comte', 46.4125000, 4.0132600, 'active', '2026-01-31 19:21:08', '2026-01-31 19:21:08'),
(3028, 'BES', 'LFRB', 'Brest Bretagne Airport', NULL, 'FR', 'Bretagne', 48.4479000, -4.4185400, 'active', '2026-01-31 19:21:08', '2026-01-31 19:21:08'),
(3029, 'DNR', 'LFRD', 'Dinard-Pleurtuit-Saint-Malo Airport', NULL, 'FR', 'Bretagne', 48.5877000, -2.0799600, 'active', '2026-01-31 19:21:09', '2026-01-31 19:21:09'),
(3030, 'LAI', 'LFRO', 'Lannion - Cote de Granit Airport', NULL, 'FR', 'Bretagne', 48.7544000, -3.4716600, 'active', '2026-01-31 19:21:09', '2026-01-31 19:21:09'),
(3031, 'LDV', 'LFRJ', 'Landivisiau Air Base', NULL, 'FR', 'Bretagne', 48.5303000, -4.1516400, 'active', '2026-01-31 19:21:09', '2026-01-31 19:21:09'),
(3032, 'LRT', 'LFRH', 'Lorient South Brittany Airport (Lann-Bihoue Airport)', NULL, 'FR', 'Bretagne', 47.7606000, -3.4400000, 'active', '2026-01-31 19:21:10', '2026-01-31 19:21:10'),
(3033, 'MXN', 'LFRU', 'Morlaix - Ploujean Airport', NULL, 'FR', 'Bretagne', 48.6032000, -3.8157800, 'active', '2026-01-31 19:21:10', '2026-01-31 19:21:10'),
(3034, 'RNS', 'LFRN', 'Rennes-Saint-Jacques Airport', NULL, 'FR', 'Bretagne', 48.0695000, -1.7347900, 'active', '2026-01-31 19:21:10', '2026-01-31 19:21:10'),
(3035, 'SBK', 'LFRT', 'Saint-Brieuc - Armor Airport', NULL, 'FR', 'Bretagne', 48.5378000, -2.8544400, 'active', '2026-01-31 19:21:11', '2026-01-31 19:21:11'),
(3036, 'UIP', 'LFRQ', 'Quimper-Cornouaille Airport', NULL, 'FR', 'Bretagne', 47.9750000, -4.1677900, 'active', '2026-01-31 19:21:11', '2026-01-31 19:21:11'),
(3037, 'VNE', 'LFRV', 'Meucon Airport', NULL, 'FR', 'Bretagne', 47.7233000, -2.7185600, 'active', '2026-01-31 19:21:11', '2026-01-31 19:21:11'),
(3038, 'BOU', 'LFLD', 'Bourges Airport', NULL, 'FR', 'Centre-Val de Loire', 47.0581000, 2.3702800, 'active', '2026-01-31 19:21:12', '2026-01-31 19:21:12'),
(3039, 'CHR', 'LFLX', 'Chateauroux-Centre Marcel Dassault Airport', NULL, 'FR', 'Centre-Val de Loire', 46.8603000, 1.7211100, 'active', '2026-01-31 19:21:12', '2026-01-31 19:21:12'),
(3040, 'ORE', 'LFOZ', 'Orleans - Saint-Denis-de-l\'Hotel port', NULL, 'FR', 'Centre-Val de Loire', 47.9878000, 1.7605600, 'active', '2026-01-31 19:21:12', '2026-01-31 19:21:12'),
(3041, 'TUF', 'LFOT', 'Tours Val de Loire Airport', NULL, 'FR', 'Centre-Val de Loire', 47.4322000, 0.7276060, 'active', '2026-01-31 19:21:13', '2026-01-31 19:21:13'),
(3042, 'AJA', 'LFKJ', 'Ajaccio Napoleon Bonaparte Airport', NULL, 'FR', 'Corse', 41.9236000, 8.8029200, 'active', '2026-01-31 19:21:13', '2026-01-31 19:21:13'),
(3043, 'BIA', 'LFKB', 'Bastia - Poretta Airport', NULL, 'FR', 'Corse', 42.5527000, 9.4837300, 'active', '2026-01-31 19:21:13', '2026-01-31 19:21:13'),
(3044, 'CLY', 'LFKC', 'Calvi - Sainte-Catherine Airport', NULL, 'FR', 'Corse', 42.5244000, 8.7930600, 'active', '2026-01-31 19:21:14', '2026-01-31 19:21:14'),
(3045, 'FSC', 'LFKF', 'Figari-Sud Corse Airport', NULL, 'FR', 'Corse', 41.5006000, 9.0977800, 'active', '2026-01-31 19:21:14', '2026-01-31 19:21:14'),
(3046, 'PRP', 'LFKO', 'Propriano Airport', NULL, 'FR', 'Corse', 41.6606000, 8.8897500, 'active', '2026-01-31 19:21:14', '2026-01-31 19:21:14'),
(3047, 'SOZ', 'LFKS', 'Solenzara Air Base', NULL, 'FR', 'Corse', 41.9244000, 9.4060000, 'active', '2026-01-31 19:21:15', '2026-01-31 19:21:15'),
(3048, 'CMR', 'LFGA', 'Colmar - Houssen Airport', NULL, 'FR', 'Grand-Est', 48.1099000, 7.3590100, 'active', '2026-01-31 19:21:15', '2026-01-31 19:21:15'),
(3049, 'ENC', 'LFSN', 'Nancy-Essey Airport', NULL, 'FR', 'Grand-Est', 48.6921000, 6.2304600, 'active', '2026-01-31 19:21:16', '2026-01-31 19:21:16'),
(3050, 'EPL', 'LFSG', 'Epinal - Mirecourt Airport', NULL, 'FR', 'Grand-Est', 48.3250000, 6.0699800, 'active', '2026-01-31 19:21:16', '2026-01-31 19:21:16'),
(3051, 'ETZ', 'LFJL', 'Metz-Nancy-Lorraine Airport', NULL, 'FR', 'Grand-Est', 48.9821000, 6.2513200, 'active', '2026-01-31 19:21:17', '2026-01-31 19:21:17'),
(3052, 'MLH', 'LFSB', 'Europort Mulhouse (Basel) Airport', NULL, 'FR', 'Grand-Est', 47.5986000, 7.5291000, 'active', '2026-01-31 19:21:17', '2026-01-31 19:21:17'),
(3053, 'MZM', 'LFSF', 'Metz-Frescaty Air Base', NULL, 'FR', 'Grand-Est', 49.0717000, 6.1316700, 'active', '2026-01-31 19:21:17', '2026-01-31 19:21:17'),
(3054, 'RHE', 'LFSR', 'Reims - Champagne Airport', NULL, 'FR', 'Grand-Est', 49.3100000, 4.0500000, 'active', '2026-01-31 19:21:18', '2026-01-31 19:21:18'),
(3055, 'SXB', 'LFST', 'Strasbourg Airport', NULL, 'FR', 'Grand-Est', 48.5383000, 7.6282300, 'active', '2026-01-31 19:21:18', '2026-01-31 19:21:18'),
(3056, 'VTL', 'LFSZ', 'Vittel - Champ-de-Courses Airport', NULL, 'FR', 'Grand-Est', 47.8168000, 6.3811100, 'active', '2026-01-31 19:21:18', '2026-01-31 19:21:18'),
(3057, 'XCR', 'LFOK', 'Chalons Vatry Airport', NULL, 'FR', 'Grand-Est', 48.7806000, 4.1883000, 'active', '2026-01-31 19:21:19', '2026-01-31 19:21:19'),
(3058, 'XCZ', 'LFQV', 'Charleville-Mézières Aerodrome', NULL, 'FR', 'Grand-Est', 49.7827000, 4.6411800, 'active', '2026-01-31 19:21:19', '2026-01-31 19:21:19'),
(3059, 'BVA', 'LFOB', 'Beauvais–Tillé Airport', NULL, 'FR', 'Hauts-de-France', 49.4544400, 2.1127700, 'active', '2026-01-31 19:21:20', '2026-01-31 19:21:20'),
(3060, 'BYF', 'LFAQ', 'Albert - Picardie Airport', NULL, 'FR', 'Hauts-de-France', 49.9715000, 2.6976600, 'active', '2026-01-31 19:21:20', '2026-01-31 19:21:20'),
(3061, 'CQF', 'LFAC', 'Calais-Dunkerque Airport', NULL, 'FR', 'Hauts-de-France', 50.9621000, 1.9547600, 'active', '2026-01-31 19:21:21', '2026-01-31 19:21:21'),
(3062, 'CSF', 'LFPC', 'Creil Air Base', NULL, 'FR', 'Hauts-de-France', 49.2535000, 2.5191400, 'active', '2026-01-31 19:21:21', '2026-01-31 19:21:21'),
(3063, 'HZB', 'LFQT', 'Merville-Calonne Airport', NULL, 'FR', 'Hauts-de-France', 50.6184000, 2.6422400, 'active', '2026-01-31 19:21:22', '2026-01-31 19:21:22'),
(3064, 'LIL', 'LFQQ', 'Lille Airport (Lille-Lesquin Airport)', NULL, 'FR', 'Hauts-de-France', 50.5633000, 3.0868900, 'active', '2026-01-31 19:21:22', '2026-01-31 19:21:22'),
(3065, 'LTQ', 'LFAT', 'Le Touquet - Cote d\'Opale Airport', NULL, 'FR', 'Hauts-de-France', 50.5174000, 1.6205900, 'active', '2026-01-31 19:21:22', '2026-01-31 19:21:22'),
(3066, 'CDG', 'LFPG', 'Paris Charles de Gaulle Airport', NULL, 'FR', 'Ile-de-France', 49.0097000, 2.5477800, 'active', '2026-01-31 19:21:23', '2026-01-31 19:21:23'),
(3067, 'ORY', 'LFPO', 'Aéroport de Paris-Orly', NULL, 'FR', 'Ile-de-France', 48.7231000, 2.3594400, 'active', '2026-01-31 19:21:23', '2026-01-31 19:21:23'),
(3068, 'XLG', 'LFPL', 'Aérodrome de Lognes - Émerainville', NULL, 'FR', 'Ile-de-France', 48.8219000, 2.6227000, 'active', '2026-01-31 19:21:23', '2026-01-31 19:21:23'),
(3069, 'TNF', 'LFPN', 'Toussus-le-Noble Airport', NULL, 'FR', 'Ile-de-France', 48.7519000, 2.1061900, 'active', '2026-01-31 19:21:24', '2026-01-31 19:21:24'),
(3070, 'LBG', 'LFPB', 'Paris–Le Bourget Airport', NULL, 'FR', 'Ile-de-France', 48.9622000, 2.4383000, 'active', '2026-01-31 19:21:24', '2026-01-31 19:21:24'),
(3071, 'CER', 'LFRC', 'Cherbourg - Maupertus Airport', NULL, 'FR', 'Normandie', 49.6501000, -1.4702800, 'active', '2026-01-31 19:21:25', '2026-01-31 19:21:25'),
(3072, 'CFR', 'LFRK', 'Caen - Carpiquet Airport', NULL, 'FR', 'Normandie', 49.1733000, -0.4500000, 'active', '2026-01-31 19:21:25', '2026-01-31 19:21:25'),
(3073, 'DOL', 'LFRG', 'Deauville - Saint-Gatien Airport', NULL, 'FR', 'Normandie', 49.3653000, 0.1543060, 'active', '2026-01-31 19:21:25', '2026-01-31 19:21:25'),
(3074, 'DPE', 'LFAB', 'Dieppe - Saint-Aubin Airport', NULL, 'FR', 'Normandie', 49.8825000, 1.0852800, 'active', '2026-01-31 19:21:26', '2026-01-31 19:21:26'),
(3075, 'EVX', 'LFOE', 'Evreux-Fauville Air Base', NULL, 'FR', 'Normandie', 49.0287000, 1.2198600, 'active', '2026-01-31 19:21:26', '2026-01-31 19:21:26'),
(3076, 'GFR', 'LFRF', 'Granville-Mont-Saint-Michel Aerodrome (fr)', NULL, 'FR', 'Normandie', 48.8831000, -1.5641700, 'active', '2026-01-31 19:21:26', '2026-01-31 19:21:26'),
(3077, 'LEH', 'LFOH', 'Le Havre - Octeville Airport', NULL, 'FR', 'Normandie', 49.5339000, 0.0880560, 'active', '2026-01-31 19:21:27', '2026-01-31 19:21:27'),
(3078, 'URO', 'LFOP', 'Rouen Airport', NULL, 'FR', 'Normandie', 49.3842000, 1.1748000, 'active', '2026-01-31 19:21:27', '2026-01-31 19:21:27'),
(3079, 'AGF', 'LFBA', 'Agen La Garenne Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 44.1747000, 0.5905560, 'active', '2026-01-31 19:21:27', '2026-01-31 19:21:27'),
(3080, 'ANG', 'LFBU', 'Angouleme - Cognac International Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 45.7292000, 0.2214560, 'active', '2026-01-31 19:21:28', '2026-01-31 19:21:28'),
(3081, 'BIQ', 'LFBZ', 'Biarritz Pays Basque Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 43.4683000, -1.5311100, 'active', '2026-01-31 19:21:28', '2026-01-31 19:21:28'),
(3082, 'BOD', 'LFBD', 'Bordeaux-Merignac Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 44.8283000, -0.7155560, 'active', '2026-01-31 19:21:28', '2026-01-31 19:21:28'),
(3083, 'BVE', 'LFSL', 'Brive-Souillac Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 45.0397000, 1.4855600, 'active', '2026-01-31 19:21:29', '2026-01-31 19:21:29'),
(3084, 'CNG', 'LFBG', 'Cognac - Chateaubernard Air Base', NULL, 'FR', 'Nouvelle-Aquitaine', 45.6583000, -0.3175000, 'active', '2026-01-31 19:21:29', '2026-01-31 19:21:29'),
(3085, 'EGC', 'LFBE', 'Bergerac Dordogne Perigord Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 44.8253000, 0.5186110, 'active', '2026-01-31 19:21:29', '2026-01-31 19:21:29'),
(3086, 'LIG', 'LFBL', 'Limoges - Bellegarde Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 45.8628000, 1.1794400, 'active', '2026-01-31 19:21:30', '2026-01-31 19:21:30'),
(3087, 'LRH', 'LFBH', 'La Rochelle - Ile de Re Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 46.1792000, -1.1952800, 'active', '2026-01-31 19:21:30', '2026-01-31 19:21:30'),
(3088, 'NIT', 'LFBN', 'Niort - Souche Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 46.3135000, -0.3945290, 'active', '2026-01-31 19:21:30', '2026-01-31 19:21:30'),
(3089, 'PGX', 'LFBX', 'Perigueux Bassillac Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 45.1981000, 0.8155560, 'active', '2026-01-31 19:21:31', '2026-01-31 19:21:31'),
(3090, 'PIS', 'LFBI', 'Poitiers-Biard Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 46.5877000, 0.3066660, 'active', '2026-01-31 19:21:31', '2026-01-31 19:21:31'),
(3091, 'PUF', 'LFBP', 'Pau Pyrenees Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 43.3800000, -0.4186110, 'active', '2026-01-31 19:21:31', '2026-01-31 19:21:31'),
(3092, 'RCO', 'LFDN', 'Rochefort - Saint-Agnant Airport', NULL, 'FR', 'Nouvelle-Aquitaine', 45.8878000, -0.9830560, 'active', '2026-01-31 19:21:32', '2026-01-31 19:21:32'),
(3093, 'RYN', 'LFCY', 'Royan - Medis Aerodrome', NULL, 'FR', 'Nouvelle-Aquitaine', 45.6281000, -0.9725000, 'active', '2026-01-31 19:21:32', '2026-01-31 19:21:32'),
(3094, 'BZR', 'LFMU', 'Beziers Cap d\'Agde Airport', NULL, 'FR', 'Occitanie', 43.3235000, 3.3539000, 'active', '2026-01-31 19:21:32', '2026-01-31 19:21:32'),
(3095, 'CCF', 'LFMK', 'Carcassonne Airport', NULL, 'FR', 'Occitanie', 43.2160000, 2.3063200, 'active', '2026-01-31 19:21:33', '2026-01-31 19:21:33'),
(3096, 'DCM', 'LFCK', 'Castres-Mazamet Airport', NULL, 'FR', 'Occitanie', 43.5563000, 2.2891800, 'active', '2026-01-31 19:21:33', '2026-01-31 19:21:33'),
(3097, 'FNI', 'LFTW', 'Nimes-Ales-Camargue-Cevennes Airport (Garons Airport)', NULL, 'FR', 'Occitanie', 43.7574000, 4.4163500, 'active', '2026-01-31 19:21:33', '2026-01-31 19:21:33'),
(3098, 'LBI', 'LFCI', 'Le Sequestre Airport', NULL, 'FR', 'Occitanie', 43.9139000, 2.1130600, 'active', '2026-01-31 19:21:34', '2026-01-31 19:21:34'),
(3099, 'LDE', 'LFBT', 'Tarbes-Lourdes-Pyrenees Airport', NULL, 'FR', 'Occitanie', 43.1787000, -0.0064390, 'active', '2026-01-31 19:21:34', '2026-01-31 19:21:34'),
(3100, 'MEN', 'LFNB', 'Brenoux Airport', NULL, 'FR', 'Occitanie', 44.5021000, 3.5328200, 'active', '2026-01-31 19:21:34', '2026-01-31 19:21:34'),
(3101, 'MPL', 'LFMT', 'Montpellier-Mediterranee Airport (Frejorgues Airport)', NULL, 'FR', 'Occitanie', 43.5762000, 3.9630100, 'active', '2026-01-31 19:21:35', '2026-01-31 19:21:35'),
(3102, 'PGF', 'LFMP', 'Perpignan-Rivesaltes Airport', NULL, 'FR', 'Occitanie', 42.7404000, 2.8706700, 'active', '2026-01-31 19:21:35', '2026-01-31 19:21:35'),
(3103, 'RDZ', 'LFCR', 'Rodez-Marcillac Airport', NULL, 'FR', 'Occitanie', 44.4079000, 2.4826700, 'active', '2026-01-31 19:21:35', '2026-01-31 19:21:35'),
(3104, 'TLS', 'LFBO', 'Toulouse-Blagnac Airport', NULL, 'FR', 'Occitanie', 43.6291000, 1.3638200, 'active', '2026-01-31 19:21:36', '2026-01-31 19:21:36'),
(3105, 'ZAO', 'LFCC', 'Cahors - Lalbenque Airport', NULL, 'FR', 'Occitanie', 44.3514000, 1.4752800, 'active', '2026-01-31 19:21:36', '2026-01-31 19:21:36'),
(3106, 'ANE', 'LFJR', 'Angers - Loire Airport', NULL, 'FR', 'Pays-de-la-Loire', 47.5603000, -0.3122220, 'active', '2026-01-31 19:21:37', '2026-01-31 19:21:37'),
(3107, 'CET', 'LFOU', 'Cholet Le Pontreau Airport', NULL, 'FR', 'Pays-de-la-Loire', 47.0821000, -0.8770640, 'active', '2026-01-31 19:21:37', '2026-01-31 19:21:37'),
(3108, 'EDM', 'LFRI', 'La Roche-sur-Yon Aerodrome', NULL, 'FR', 'Pays-de-la-Loire', 46.7019000, -1.3786300, 'active', '2026-01-31 19:21:37', '2026-01-31 19:21:37'),
(3109, 'IDY', 'LFEY', 'Ile d\'Yeu Aerodrome', NULL, 'FR', 'Pays-de-la-Loire', 46.7186000, -2.3911100, 'active', '2026-01-31 19:21:38', '2026-01-31 19:21:38'),
(3110, 'LBY', 'LFRE', 'La Baule-Escoublac Airport', NULL, 'FR', 'Pays-de-la-Loire', 47.2894000, -2.3463900, 'active', '2026-01-31 19:21:38', '2026-01-31 19:21:38'),
(3111, 'LME', 'LFRM', 'Le Mans Arnage Airport', NULL, 'FR', 'Pays-de-la-Loire', 47.9486000, 0.2016670, 'active', '2026-01-31 19:21:38', '2026-01-31 19:21:38'),
(3112, 'LSO', 'LFOO', 'Les Sables-d\'Olonne - Talmont Airport', NULL, 'FR', 'Pays-de-la-Loire', 46.4769000, -1.7227800, 'active', '2026-01-31 19:21:39', '2026-01-31 19:21:39'),
(3113, 'LVA', 'LFOV', 'Laval Entrammes Airport', NULL, 'FR', 'Pays-de-la-Loire', 48.0314000, -0.7429860, 'active', '2026-01-31 19:21:39', '2026-01-31 19:21:39'),
(3114, 'NTE', 'LFRS', 'Nantes Atlantique Airport', NULL, 'FR', 'Pays-de-la-Loire', 47.1532000, -1.6107300, 'active', '2026-01-31 19:21:39', '2026-01-31 19:21:39'),
(3115, 'SNR', 'LFRZ', 'Saint-Nazaire Montoir Airport', NULL, 'FR', 'Pays-de-la-Loire', 47.3106000, -2.1566700, 'active', '2026-01-31 19:21:40', '2026-01-31 19:21:40'),
(3116, 'AVN', 'LFMV', 'Avignon - Provence Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.9073000, 4.9018300, 'active', '2026-01-31 19:21:40', '2026-01-31 19:21:40'),
(3117, 'BAE', 'LFMR', 'Barcelonnette - Saint-Pons Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 44.3872000, 6.6091900, 'active', '2026-01-31 19:21:40', '2026-01-31 19:21:40'),
(3118, 'CEQ', 'LFMD', 'Cannes - Mandelieu Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.5420000, 6.9534800, 'active', '2026-01-31 19:21:41', '2026-01-31 19:21:41'),
(3119, 'CTT', 'LFMQ', 'Le Castellet Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.2525000, 5.7851900, 'active', '2026-01-31 19:21:41', '2026-01-31 19:21:41'),
(3120, 'GAT', 'LFNA', 'Gap-Tallard Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 44.4550000, 6.0377800, 'active', '2026-01-31 19:21:41', '2026-01-31 19:21:41'),
(3121, 'LTT', 'LFTZ', 'La Mole - Saint-Tropez Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.2054000, 6.4820000, 'active', '2026-01-31 19:21:42', '2026-01-31 19:21:42'),
(3122, 'MRS', 'LFML', 'Marseille Provence Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.4393000, 5.2214200, 'active', '2026-01-31 19:21:42', '2026-01-31 19:21:42'),
(3123, 'NCE', 'LFMN', 'Nice Cote d\'Azur Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.6584000, 7.2158700, 'active', '2026-01-31 19:21:42', '2026-01-31 19:21:42'),
(3124, 'QIE', 'LFMI', 'Istres-Le Tubé Air Base', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.5244000, 4.9416700, 'active', '2026-01-31 19:21:43', '2026-01-31 19:21:43'),
(3125, 'QXB', 'LFMA', 'Aix-en-Provence Aerodrome', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.5056000, 5.3677800, 'active', '2026-01-31 19:21:43', '2026-01-31 19:21:43'),
(3126, 'SCP', 'LFNC', 'Mont-Dauphin - Saint-Crepin Airport', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 44.7017000, 6.6002800, 'active', '2026-01-31 19:21:43', '2026-01-31 19:21:43'),
(3127, 'TLN', 'LFTH', 'Toulon-Hyeres Airport (Hyeres Le Palyvestre Airport)', NULL, 'FR', 'Provence-Alpes-Cote-d\'Azur', 43.0973000, 6.1460300, 'active', '2026-01-31 19:21:44', '2026-01-31 19:21:44'),
(3128, 'LBV', 'FOOL', 'Léon-Mba International Airport', NULL, 'GA', 'Estuaire', 0.4586110, 9.4122200, 'active', '2026-01-31 19:21:44', '2026-01-31 19:21:44'),
(3129, 'NKA', NULL, 'Nkan Airport', NULL, 'GA', 'Estuaire', 0.7000000, 9.9833300, 'active', '2026-01-31 19:21:44', '2026-01-31 19:21:44'),
(3130, 'OWE', NULL, 'Owendo Airport', NULL, 'GA', 'Estuaire', 0.3000000, 9.5000000, 'active', '2026-01-31 19:21:45', '2026-01-31 19:21:45'),
(3131, 'AKE', 'FOGA', 'Akieni Airport', NULL, 'GA', 'Haut-Ogooue', -1.1396700, 13.9036000, 'active', '2026-01-31 19:21:45', '2026-01-31 19:21:45'),
(3132, 'LEO', NULL, 'Lekoni Airport', NULL, 'GA', 'Haut-Ogooue', -1.5724000, 14.2878000, 'active', '2026-01-31 19:21:45', '2026-01-31 19:21:45'),
(3133, 'MFF', 'FOOD', 'Moanda Airport', NULL, 'GA', 'Haut-Ogooue', -1.5330000, 13.2670000, 'active', '2026-01-31 19:21:46', '2026-01-31 19:21:46'),
(3134, 'MVB', 'FOON', 'M\'Vengue El Hadj Omar Bongo Ondimba International Airport', NULL, 'GA', 'Haut-Ogooue', -1.6561600, 13.4380000, 'active', '2026-01-31 19:21:46', '2026-01-31 19:21:46'),
(3135, 'OKN', 'FOGQ', 'Okondja Airport', NULL, 'GA', 'Haut-Ogooue', -0.6652140, 13.6731000, 'active', '2026-01-31 19:21:46', '2026-01-31 19:21:46'),
(3136, 'GIM', NULL, 'Miele Mimbale Airport', NULL, 'GA', 'Moyen-Ogooue', -0.0166667, 11.4000000, 'active', '2026-01-31 19:21:47', '2026-01-31 19:21:47'),
(3137, 'GKO', NULL, 'Kongo Boumba Airport', NULL, 'GA', 'Moyen-Ogooue', -0.0833333, 11.4667000, 'active', '2026-01-31 19:21:47', '2026-01-31 19:21:47'),
(3138, 'KDJ', 'FOGJ', 'Ndjole Ville Airport', NULL, 'GA', 'Moyen-Ogooue', -0.1830000, 10.7500000, 'active', '2026-01-31 19:21:48', '2026-01-31 19:21:48'),
(3139, 'LBQ', 'FOGR', 'Lambarene Airport', NULL, 'GA', 'Moyen-Ogooue', -0.7043890, 10.2457000, 'active', '2026-01-31 19:21:48', '2026-01-31 19:21:48'),
(3140, 'MVG', NULL, 'Mevang Airport', NULL, 'GA', 'Moyen-Ogooue', 0.0833300, 11.0833000, 'active', '2026-01-31 19:21:48', '2026-01-31 19:21:48'),
(3141, 'FOU', 'FOGF', 'Fougamou Airport', NULL, 'GA', 'Ngounie', -1.2830000, 10.6170000, 'active', '2026-01-31 19:21:49', '2026-01-31 19:21:49'),
(3142, 'KDN', 'FOGE', 'Ndende Airport', NULL, 'GA', 'Ngounie', -2.4000000, 11.3670000, 'active', '2026-01-31 19:21:49', '2026-01-31 19:21:49'),
(3143, 'MBC', 'FOGG', 'Mbigou Airport', NULL, 'GA', 'Ngounie', -1.8830000, 11.9330000, 'active', '2026-01-31 19:21:49', '2026-01-31 19:21:49'),
(3144, 'MGO', NULL, 'Manega Airport', NULL, 'GA', 'Ngounie', -1.7333300, 10.2167000, 'active', '2026-01-31 19:21:50', '2026-01-31 19:21:50'),
(3145, 'MJL', 'FOGM', 'Mouila Airport', NULL, 'GA', 'Ngounie', -1.8451400, 11.0567000, 'active', '2026-01-31 19:21:51', '2026-01-31 19:21:51'),
(3146, 'MGX', 'FOGI', 'Moabi Airport', NULL, 'GA', 'Nyanga', -2.4330000, 11.0000000, 'active', '2026-01-31 19:21:51', '2026-01-31 19:21:51'),
(3147, 'MYB', 'FOOY', 'Mayumba Airport', NULL, 'GA', 'Nyanga', -3.4584200, 10.6741000, 'active', '2026-01-31 19:21:52', '2026-01-31 19:21:52'),
(3148, 'TCH', 'FOOT', 'Tchibanga Airport', NULL, 'GA', 'Nyanga', -2.8500000, 11.0170000, 'active', '2026-01-31 19:21:52', '2026-01-31 19:21:52'),
(3149, 'BGB', 'FOGB', 'Booue Airport', NULL, 'GA', 'Ogooue-Ivindo', -0.1075000, 11.9438000, 'active', '2026-01-31 19:21:53', '2026-01-31 19:21:53'),
(3150, 'GAX', NULL, 'Gamba Airport', NULL, 'GA', 'Ogooue-Ivindo', -2.7852800, 10.0472000, 'active', '2026-01-31 19:21:53', '2026-01-31 19:21:53'),
(3151, 'MKB', 'FOOE', 'Mekambo Airport', NULL, 'GA', 'Ogooue-Ivindo', 1.0170000, 13.9330000, 'active', '2026-01-31 19:21:53', '2026-01-31 19:21:53'),
(3152, 'MKU', 'FOOK', 'Makokou Airport', NULL, 'GA', 'Ogooue-Ivindo', 0.5792110, 12.8909000, 'active', '2026-01-31 19:21:54', '2026-01-31 19:21:54'),
(3153, 'WGY', NULL, 'Wagny Airport', NULL, 'GA', 'Ogooue-Ivindo', -0.6035000, 12.2608000, 'active', '2026-01-31 19:21:54', '2026-01-31 19:21:54'),
(3154, 'KOU', 'FOGK', 'Koulamoutou Airport', NULL, 'GA', 'Ogooue-Lolo', -1.1846100, 12.4413000, 'active', '2026-01-31 19:21:54', '2026-01-31 19:21:54'),
(3155, 'LTL', 'FOOR', 'Lastourville Airport', NULL, 'GA', 'Ogooue-Lolo', -0.8266670, 12.7486000, 'active', '2026-01-31 19:21:55', '2026-01-31 19:21:55'),
(3156, 'AWE', 'FOGW', 'Alowe Airport', NULL, 'GA', 'Ogooue-Maritime', -0.5450000, 9.4440000, 'active', '2026-01-31 19:21:55', '2026-01-31 19:21:55'),
(3157, 'BAW', NULL, 'Biawonque Airport', NULL, 'GA', 'Ogooue-Maritime', -0.6666670, 9.4500000, 'active', '2026-01-31 19:21:55', '2026-01-31 19:21:55'),
(3158, 'BGP', NULL, 'Bongo Airport', NULL, 'GA', 'Ogooue-Maritime', -2.1713000, 10.2088000, 'active', '2026-01-31 19:21:56', '2026-01-31 19:21:56'),
(3159, 'IGE', 'FOOI', 'Tchongorove Airport', NULL, 'GA', 'Ogooue-Maritime', -1.9223000, 9.3092000, 'active', '2026-01-31 19:21:56', '2026-01-31 19:21:56'),
(3160, 'OMB', 'FOOH', 'Omboue Hospital Airport', NULL, 'GA', 'Ogooue-Maritime', -1.5747300, 9.2626900, 'active', '2026-01-31 19:21:56', '2026-01-31 19:21:56'),
(3161, 'OUU', NULL, 'Ouanga Airport', NULL, 'GA', 'Ogooue-Maritime', -2.9833300, 10.3000000, 'active', '2026-01-31 19:21:57', '2026-01-31 19:21:57'),
(3162, 'POG', 'FOOG', 'Port-Gentil International Airport', NULL, 'GA', 'Ogooue-Maritime', -0.7117390, 8.7543800, 'active', '2026-01-31 19:21:57', '2026-01-31 19:21:57'),
(3163, 'WNE', NULL, 'Wora na Yeno Airport', NULL, 'GA', 'Ogooue-Maritime', -1.3500000, 9.3333300, 'active', '2026-01-31 19:21:57', '2026-01-31 19:21:57'),
(3164, 'BMM', 'FOOB', 'Bitam Airport', NULL, 'GA', 'Woleu-Ntem', 2.0756400, 11.4932000, 'active', '2026-01-31 19:21:58', '2026-01-31 19:21:58'),
(3165, 'MDV', NULL, 'Medouneu Airport', NULL, 'GA', 'Woleu-Ntem', 1.0085000, 10.7552000, 'active', '2026-01-31 19:21:58', '2026-01-31 19:21:58'),
(3166, 'MVX', 'FOGV', 'Minvoul Airport', NULL, 'GA', 'Woleu-Ntem', 2.1500000, 12.1330000, 'active', '2026-01-31 19:21:58', '2026-01-31 19:21:58'),
(3167, 'MZC', 'FOOM', 'Mitzic Airport', NULL, 'GA', 'Woleu-Ntem', 0.7830000, 11.5500000, 'active', '2026-01-31 19:21:59', '2026-01-31 19:21:59'),
(3168, 'OYE', 'FOGO', 'Oyem Airport', NULL, 'GA', 'Woleu-Ntem', 1.5431100, 11.5814000, 'active', '2026-01-31 19:21:59', '2026-01-31 19:21:59'),
(3169, 'HYC', 'EGTB', 'Wycombe Air Park Airport', NULL, 'GB', 'Buckinghamshire', 51.6117000, -0.8083330, 'active', '2026-01-31 19:21:59', '2026-01-31 19:21:59'),
(3170, 'PLH', 'EGHD', 'Plymouth City Airport', NULL, 'GB', 'Devon', 50.4228000, -4.1058300, 'active', '2026-01-31 19:22:00', '2026-01-31 19:22:00'),
(3171, 'BBP', 'EGHJ', 'Bembridge Airport', NULL, 'GB', 'England', 50.6781000, -1.1094400, 'active', '2026-01-31 19:22:00', '2026-01-31 19:22:00'),
(3172, 'BBS', 'EGLK', 'Blackbushe Airport', NULL, 'GB', 'England', 51.3239000, -0.8475000, 'active', '2026-01-31 19:22:00', '2026-01-31 19:22:00'),
(3173, 'BEQ', 'EGXH', 'RAF Honington', NULL, 'GB', 'England', 52.3426000, 0.7729390, 'active', '2026-01-31 19:22:01', '2026-01-31 19:22:01'),
(3174, 'BEX', 'EGUB', 'RAF Benson', NULL, 'GB', 'England', 51.6164000, -1.0958300, 'active', '2026-01-31 19:22:01', '2026-01-31 19:22:01'),
(3175, 'BHX', 'EGBB', 'Birmingham Airport', NULL, 'GB', 'England', 52.4539000, -1.7480300, 'active', '2026-01-31 19:22:01', '2026-01-31 19:22:01'),
(3176, 'BLK', 'EGNH', 'Blackpool Airport', NULL, 'GB', 'England', 53.7717000, -3.0286100, 'active', '2026-01-31 19:22:02', '2026-01-31 19:22:02'),
(3177, 'BOH', 'EGHH', 'Bournemouth Airport', NULL, 'GB', 'England', 50.7800000, -1.8425000, 'active', '2026-01-31 19:22:02', '2026-01-31 19:22:02'),
(3178, 'BQH', 'EGKB', 'London Biggin Hill Airport', NULL, 'GB', 'England', 51.3308000, 0.0325000, 'active', '2026-01-31 19:22:03', '2026-01-31 19:22:03'),
(3179, 'BRS', 'EGGD', 'Bristol Airport', NULL, 'GB', 'England', 51.3827000, -2.7190900, 'active', '2026-01-31 19:22:03', '2026-01-31 19:22:03'),
(3180, 'BWF', 'EGNL', 'Barrow/Walney Island Airport', NULL, 'GB', 'England', 54.1286000, -3.2675000, 'active', '2026-01-31 19:22:03', '2026-01-31 19:22:03'),
(3181, 'BZZ', 'EGVN', 'RAF Brize Norton', NULL, 'GB', 'England', 51.7500000, -1.5836200, 'active', '2026-01-31 19:22:04', '2026-01-31 19:22:04'),
(3182, 'CAX', 'EGNC', 'Carlisle Lake District Airport', NULL, 'GB', 'England', 54.9375000, -2.8091700, 'active', '2026-01-31 19:22:04', '2026-01-31 19:22:04'),
(3183, 'CBG', 'EGSC', 'Cambridge Airport', NULL, 'GB', 'England', 52.2050000, 0.1750000, 'active', '2026-01-31 19:22:04', '2026-01-31 19:22:04'),
(3184, 'CVT', 'EGBE', 'Coventry Airport', NULL, 'GB', 'England', 52.3697000, -1.4797200, 'active', '2026-01-31 19:22:05', '2026-01-31 19:22:05'),
(3185, 'DSA', 'EGCN', 'Robin Hood Airport Doncaster Sheffield', NULL, 'GB', 'England', 53.4805000, -1.0106600, 'active', '2026-01-31 19:22:05', '2026-01-31 19:22:05'),
(3186, 'EMA', 'EGNX', 'East Midlands Airport', NULL, 'GB', 'England', 52.8311000, -1.3280600, 'active', '2026-01-31 19:22:05', '2026-01-31 19:22:05'),
(3187, 'EXT', 'EGTE', 'Exeter International Airport', NULL, 'GB', 'England', 50.7344000, -3.4138900, 'active', '2026-01-31 19:22:06', '2026-01-31 19:22:06'),
(3188, 'FAB', 'EGLF', 'Farnborough Airport', NULL, 'GB', 'England', 51.2758000, -0.7763330, 'active', '2026-01-31 19:22:06', '2026-01-31 19:22:06'),
(3189, 'FFD', 'EGVA', 'RAF Fairford', NULL, 'GB', 'England', 51.6822000, -1.7900300, 'active', '2026-01-31 19:22:06', '2026-01-31 19:22:06'),
(3190, 'GBA', 'EGBP', 'Cotswold Airport', NULL, 'GB', 'England', 51.6681000, -2.0569400, 'active', '2026-01-31 19:22:07', '2026-01-31 19:22:07'),
(3191, 'GLO', 'EGBJ', 'Gloucestershire Airport', NULL, 'GB', 'England', 51.8942000, -2.1672200, 'active', '2026-01-31 19:22:07', '2026-01-31 19:22:07'),
(3192, 'HRT', 'EGXU', 'RAF Linton-on-Ouse', NULL, 'GB', 'England', 54.0489000, -1.2527500, 'active', '2026-01-31 19:22:07', '2026-01-31 19:22:07'),
(3193, 'HUY', 'EGNJ', 'Humberside Airport', NULL, 'GB', 'England', 53.5744000, -0.3508330, 'active', '2026-01-31 19:22:08', '2026-01-31 19:22:08'),
(3194, 'IOM', 'EGNS', 'Isle of Man Airport', NULL, 'GB', 'England', 54.0833000, -4.6233300, 'active', '2026-01-31 19:22:08', '2026-01-31 19:22:08'),
(3195, 'ISC', 'EGHE', 'St Mary\'s Airport', NULL, 'GB', 'England', 49.9133000, -6.2916700, 'active', '2026-01-31 19:22:08', '2026-01-31 19:22:08'),
(3196, 'KNF', 'EGYM', 'RAF Marham', NULL, 'GB', 'England', 52.6484000, 0.5506920, 'active', '2026-01-31 19:22:09', '2026-01-31 19:22:09'),
(3197, 'KRH', 'EGKR', 'Redhill Aerodrome', NULL, 'GB', 'England', 51.2136000, -0.1386110, 'active', '2026-01-31 19:22:09', '2026-01-31 19:22:09'),
(3198, 'LBA', 'EGNM', 'Leeds Bradford Airport', NULL, 'GB', 'England', 53.8659000, -1.6605700, 'active', '2026-01-31 19:22:09', '2026-01-31 19:22:09'),
(3199, 'LCY', 'EGLC', 'London City Airport', NULL, 'GB', 'England', 51.5053000, 0.0552780, 'active', '2026-01-31 19:22:10', '2026-01-31 19:22:10'),
(3200, 'LEQ', 'EGHC', 'Land\'s End Airport', NULL, 'GB', 'England', 50.1028000, -5.6705600, 'active', '2026-01-31 19:22:10', '2026-01-31 19:22:10'),
(3201, 'LGW', 'EGKK', 'Gatwick Airport', NULL, 'GB', 'England', 51.1481000, -0.1902780, 'active', '2026-01-31 19:22:10', '2026-01-31 19:22:10'),
(3202, 'LHB', 'EG74', 'Bruntingthorpe Aerodrome (Leicester Harboro\'/Harbour Airport)', NULL, 'GB', 'England', 52.4908000, -1.1312000, 'active', '2026-01-31 19:22:11', '2026-01-31 19:22:11'),
(3203, 'LHR', 'EGLL', 'Heathrow Airport', NULL, 'GB', 'England', 51.4775000, -0.4613890, 'active', '2026-01-31 19:22:11', '2026-01-31 19:22:11'),
(3204, 'LKZ', 'EGUL', 'RAF Lakenheath', NULL, 'GB', 'England', 52.4093000, 0.5610000, 'active', '2026-01-31 19:22:12', '2026-01-31 19:22:12'),
(3205, 'LPL', 'EGGP', 'Liverpool John Lennon Airport', NULL, 'GB', 'England', 53.3336000, -2.8497200, 'active', '2026-01-31 19:22:13', '2026-01-31 19:22:13'),
(3206, 'LTN', 'EGGW', 'London Luton Airport', NULL, 'GB', 'England', 51.8747000, -0.3683330, 'active', '2026-01-31 19:22:13', '2026-01-31 19:22:13'),
(3207, 'LYE', 'EGDL', 'RAF Lyneham', NULL, 'GB', 'England', 51.5051000, -1.9934300, 'active', '2026-01-31 19:22:13', '2026-01-31 19:22:13'),
(3208, 'LYX', 'EGMD', 'Lydd Airport (London Ashford Airport)', NULL, 'GB', 'England', 50.9561000, 0.9391670, 'active', '2026-01-31 19:22:14', '2026-01-31 19:22:14'),
(3209, 'MAN', 'EGCC', 'Manchester Airport', NULL, 'GB', 'England', 53.3537000, -2.2749500, 'active', '2026-01-31 19:22:14', '2026-01-31 19:22:14'),
(3210, 'MHZ', 'EGUN', 'RAF Mildenhall', NULL, 'GB', 'England', 52.3619000, 0.4864060, 'active', '2026-01-31 19:22:14', '2026-01-31 19:22:14'),
(3211, 'MME', 'EGNV', 'Teesside International Airport', NULL, 'GB', 'England', 54.5092000, -1.4294100, 'active', '2026-01-31 19:22:15', '2026-01-31 19:22:15'),
(3212, 'NCL', 'EGNT', 'Newcastle Airport', NULL, 'GB', 'England', 55.0375000, -1.6916700, 'active', '2026-01-31 19:22:15', '2026-01-31 19:22:15'),
(3213, 'NHT', 'EGWU', 'RAF Northolt', NULL, 'GB', 'England', 51.5530000, -0.4181670, 'active', '2026-01-31 19:22:15', '2026-01-31 19:22:15'),
(3214, 'NQT', 'EGBN', 'Nottingham Airport', NULL, 'GB', 'England', 52.9200000, -1.0791700, 'active', '2026-01-31 19:22:16', '2026-01-31 19:22:16'),
(3215, 'NQY', 'EGHQ', 'Cornwall Airport Newquay', NULL, 'GB', 'England', 50.4406000, -4.9954100, 'active', '2026-01-31 19:22:16', '2026-01-31 19:22:16'),
(3216, 'NWI', 'EGSH', 'Norwich International Airport', NULL, 'GB', 'England', 52.6758000, 1.2827800, 'active', '2026-01-31 19:22:16', '2026-01-31 19:22:16'),
(3217, 'ODH', 'EGVO', 'RAF Odiham', NULL, 'GB', 'England', 51.2341000, -0.9428250, 'active', '2026-01-31 19:22:17', '2026-01-31 19:22:17'),
(3218, 'ORM', 'EGBK', 'Sywell Aerodrome', NULL, 'GB', 'England', 52.3053000, -0.7930560, 'active', '2026-01-31 19:22:17', '2026-01-31 19:22:17'),
(3219, 'OXF', 'EGTK', 'Oxford Airport (London Oxford Airport)', NULL, 'GB', 'England', 51.8369000, -1.3200000, 'active', '2026-01-31 19:22:17', '2026-01-31 19:22:17'),
(3220, 'QCY', 'EGXC', 'RAF Coningsby', NULL, 'GB', 'England', 53.0930000, -0.1660140, 'active', '2026-01-31 19:22:18', '2026-01-31 19:22:18'),
(3221, 'QFO', 'EGSU', 'Duxford Aerodrome', NULL, 'GB', 'England', 52.0908000, 0.1319440, 'active', '2026-01-31 19:22:18', '2026-01-31 19:22:18'),
(3222, 'QLA', 'EGHL', 'Lasham Airfield', NULL, 'GB', 'England', 51.1872000, -1.0336100, 'active', '2026-01-31 19:22:18', '2026-01-31 19:22:18'),
(3223, 'QUG', 'EGHR', 'Chichester/Goodwood Airport', NULL, 'GB', 'England', 50.8594000, -0.7591670, 'active', '2026-01-31 19:22:19', '2026-01-31 19:22:19'),
(3224, 'QUY', 'EGUY', 'RAF Wyton', NULL, 'GB', 'England', 52.3572000, -0.1078330, 'active', '2026-01-31 19:22:19', '2026-01-31 19:22:19'),
(3225, 'RCS', 'EGTO', 'Rochester Airport', NULL, 'GB', 'England', 51.3519000, 0.5033330, 'active', '2026-01-31 19:22:19', '2026-01-31 19:22:19'),
(3226, 'SEN', 'EGMC', 'London Southend Airport', NULL, 'GB', 'England', 51.5703000, 0.6933330, 'active', '2026-01-31 19:22:20', '2026-01-31 19:22:20'),
(3227, 'SOU', 'EGHI', 'Southampton Airport', NULL, 'GB', 'England', 50.9503000, -1.3568000, 'active', '2026-01-31 19:22:20', '2026-01-31 19:22:20'),
(3228, 'SQZ', 'EGXP', 'RAF Scampton', NULL, 'GB', 'England', 53.3078000, -0.5508330, 'active', '2026-01-31 19:22:20', '2026-01-31 19:22:20'),
(3229, 'STN', 'EGSS', 'London Stansted Airport', NULL, 'GB', 'England', 51.8850000, 0.2350000, 'active', '2026-01-31 19:22:21', '2026-01-31 19:22:21'),
(3230, 'UPV', 'EGDJ', 'RAF Upavon', NULL, 'GB', 'England', 51.2862000, -1.7820200, 'active', '2026-01-31 19:22:21', '2026-01-31 19:22:21'),
(3231, 'WTN', 'EGXW', 'RAF Waddington', NULL, 'GB', 'England', 53.1662000, -0.5238110, 'active', '2026-01-31 19:22:21', '2026-01-31 19:22:21'),
(3232, 'YEO', 'EGDY', 'Royal Naval Air Station Yeovilton', NULL, 'GB', 'England', 51.0094000, -2.6388200, 'active', '2026-01-31 19:22:22', '2026-01-31 19:22:22');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(3233, 'GCI', 'EGJB', 'Guernsey Airport', NULL, 'GB', 'Great Britain', 49.4347000, -2.6019400, 'active', '2026-01-31 19:22:22', '2026-01-31 19:22:22'),
(3234, 'ACI', 'EGJA', 'Alderney Airport', NULL, 'GB', 'Guernsey', 49.7067000, -2.2144400, 'active', '2026-01-31 19:22:22', '2026-01-31 19:22:22'),
(3235, 'MSE', 'EGMH', 'Manston Airport', NULL, 'GB', 'Kent', 51.3422000, 1.3461100, 'active', '2026-01-31 19:22:23', '2026-01-31 19:22:23'),
(3236, 'WRT', 'EGNO', 'Warton Aerodrome', NULL, 'GB', 'Lancashire', 53.7450000, -2.8838900, 'active', '2026-01-31 19:22:23', '2026-01-31 19:22:23'),
(3237, 'BFS', 'EGAA', 'Belfast International Airport', NULL, 'GB', 'Northern Ireland', 54.6575000, -6.2158300, 'active', '2026-01-31 19:22:23', '2026-01-31 19:22:23'),
(3238, 'BHD', 'EGAC', 'George Best Belfast City Airport', NULL, 'GB', 'Northern Ireland', 54.6181000, -5.8725000, 'active', '2026-01-31 19:22:24', '2026-01-31 19:22:24'),
(3239, 'BOL', 'EGQB', 'Ballykelly Airfield (RAF Ballykelly)', NULL, 'GB', 'Northern Ireland', 55.0544000, -7.0200000, 'active', '2026-01-31 19:22:24', '2026-01-31 19:22:24'),
(3240, 'ENK', 'EGAB', 'Enniskillen/St Angelo Airport', NULL, 'GB', 'Northern Ireland', 54.3989000, -7.6516700, 'active', '2026-01-31 19:22:24', '2026-01-31 19:22:24'),
(3241, 'LDY', 'EGAE', 'City of Derry Airport', NULL, 'GB', 'Northern Ireland', 55.0428000, -7.1611100, 'active', '2026-01-31 19:22:25', '2026-01-31 19:22:25'),
(3242, 'OKH', 'EGXJ', 'RAF Cottesmore', NULL, 'GB', 'Rutland', 52.7294000, -0.6513890, 'active', '2026-01-31 19:22:25', '2026-01-31 19:22:25'),
(3243, 'ABZ', 'EGPD', 'Aberdeen Airport', NULL, 'GB', 'Scotland', 57.2019000, -2.1977800, 'active', '2026-01-31 19:22:25', '2026-01-31 19:22:25'),
(3244, 'ADX', 'EGQL', 'RAF Leuchars', NULL, 'GB', 'Scotland', 56.3729000, -2.8684400, 'active', '2026-01-31 19:22:26', '2026-01-31 19:22:26'),
(3245, 'BEB', 'EGPL', 'Benbecula Airport', NULL, 'GB', 'Scotland', 57.4811000, -7.3627800, 'active', '2026-01-31 19:22:26', '2026-01-31 19:22:26'),
(3246, 'BRR', 'EGPR', 'Barra Airport', NULL, 'GB', 'Scotland', 57.0228000, -7.4430600, 'active', '2026-01-31 19:22:26', '2026-01-31 19:22:26'),
(3247, 'CAL', 'EGEC', 'Campbeltown Airport / RAF Machrihanish', NULL, 'GB', 'Scotland', 55.4372000, -5.6863900, 'active', '2026-01-31 19:22:27', '2026-01-31 19:22:27'),
(3248, 'COL', NULL, 'Coll Airport', NULL, 'GB', 'Scotland', 56.6019000, -6.6177800, 'active', '2026-01-31 19:22:27', '2026-01-31 19:22:27'),
(3249, 'CSA', NULL, 'Colonsay Airport', NULL, 'GB', 'Scotland', 56.0575000, -6.2430600, 'active', '2026-01-31 19:22:27', '2026-01-31 19:22:27'),
(3250, 'DND', 'EGPN', 'Dundee Airport', NULL, 'GB', 'Scotland', 56.4525000, -3.0258300, 'active', '2026-01-31 19:22:28', '2026-01-31 19:22:28'),
(3251, 'DOC', NULL, 'Dornoch Airport', NULL, 'GB', 'Scotland', 57.8690000, -4.0230000, 'active', '2026-01-31 19:22:28', '2026-01-31 19:22:28'),
(3252, 'EDI', 'EGPH', 'Edinburgh Airport', NULL, 'GB', 'Scotland', 55.9500000, -3.3725000, 'active', '2026-01-31 19:22:28', '2026-01-31 19:22:28'),
(3253, 'EOI', 'EGED', 'Eday Airport', NULL, 'GB', 'Scotland', 59.1906000, -2.7722200, 'active', '2026-01-31 19:22:29', '2026-01-31 19:22:29'),
(3254, 'FIE', 'EGEF', 'Fair Isle Airport', NULL, 'GB', 'Scotland', 59.5358000, -1.6280600, 'active', '2026-01-31 19:22:29', '2026-01-31 19:22:29'),
(3255, 'FOA', NULL, 'Foula Airfield', NULL, 'GB', 'Scotland', 60.1217000, -2.0532000, 'active', '2026-01-31 19:22:29', '2026-01-31 19:22:29'),
(3256, 'FSS', 'EGQK', 'RAF Kinloss', NULL, 'GB', 'Scotland', 57.6494000, -3.5606400, 'active', '2026-01-31 19:22:30', '2026-01-31 19:22:30'),
(3257, 'GLA', 'EGPF', 'Glasgow Airport', NULL, 'GB', 'Scotland', 55.8719000, -4.4330600, 'active', '2026-01-31 19:22:30', '2026-01-31 19:22:30'),
(3258, 'ILY', 'EGPI', 'Islay Airport (Glenegedale Airport)', NULL, 'GB', 'Scotland', 55.6819000, -6.2566700, 'active', '2026-01-31 19:22:30', '2026-01-31 19:22:30'),
(3259, 'INV', 'EGPE', 'Inverness Airport', NULL, 'GB', 'Scotland', 57.5425000, -4.0475000, 'active', '2026-01-31 19:22:31', '2026-01-31 19:22:31'),
(3260, 'KOI', 'EGPA', 'Kirkwall Airport', NULL, 'GB', 'Scotland', 58.9578000, -2.9050000, 'active', '2026-01-31 19:22:31', '2026-01-31 19:22:31'),
(3261, 'LMO', 'EGQS', 'RAF Lossiemouth', NULL, 'GB', 'Scotland', 57.7052000, -3.3391700, 'active', '2026-01-31 19:22:31', '2026-01-31 19:22:31'),
(3262, 'LSI', 'EGPB', 'Sumburgh Airport', NULL, 'GB', 'Scotland', 59.8814000, -1.2938900, 'active', '2026-01-31 19:22:32', '2026-01-31 19:22:32'),
(3263, 'LWK', 'EGET', 'Tingwall Airport', NULL, 'GB', 'Scotland', 60.1919000, -1.2436100, 'active', '2026-01-31 19:22:32', '2026-01-31 19:22:32'),
(3264, 'NDY', 'EGES', 'Sanday Airport', NULL, 'GB', 'Scotland', 59.2503000, -2.5766700, 'active', '2026-01-31 19:22:32', '2026-01-31 19:22:32'),
(3265, 'NRL', 'EGEN', 'North Ronaldsay Airport', NULL, 'GB', 'Scotland', 59.3675000, -2.4344400, 'active', '2026-01-31 19:22:33', '2026-01-31 19:22:33'),
(3266, 'OBN', 'EGEO', 'Oban Airport (North Connel Airport)', NULL, 'GB', 'Scotland', 56.4635000, -5.3996700, 'active', '2026-01-31 19:22:33', '2026-01-31 19:22:33'),
(3267, 'OUK', NULL, 'Out Skerries Airport', NULL, 'GB', 'Scotland', 60.4252000, -0.7500000, 'active', '2026-01-31 19:22:33', '2026-01-31 19:22:33'),
(3268, 'PIK', 'EGPK', 'Glasgow Prestwick Airport', NULL, 'GB', 'Scotland', 55.5094000, -4.5866700, 'active', '2026-01-31 19:22:34', '2026-01-31 19:22:34'),
(3269, 'PPW', 'EGEP', 'Papa Westray Airport', NULL, 'GB', 'Scotland', 59.3517000, -2.9002800, 'active', '2026-01-31 19:22:34', '2026-01-31 19:22:34'),
(3270, 'PSL', 'EGPT', 'Perth Airport (Scone Airport)', NULL, 'GB', 'Scotland', 56.4392000, -3.3722200, 'active', '2026-01-31 19:22:35', '2026-01-31 19:22:35'),
(3271, 'PSV', NULL, 'Papa Stour Airport', NULL, 'GB', 'Scotland', 60.3217000, -1.6930600, 'active', '2026-01-31 19:22:35', '2026-01-31 19:22:35'),
(3272, 'SKL', 'EGEI', 'Broadford Airfield', NULL, 'GB', 'Scotland', 57.2414000, -5.9096600, 'active', '2026-01-31 19:22:35', '2026-01-31 19:22:35'),
(3273, 'SOY', 'EGER', 'Stronsay Airport', NULL, 'GB', 'Scotland', 59.1553000, -2.6413900, 'active', '2026-01-31 19:22:36', '2026-01-31 19:22:36'),
(3274, 'SYY', 'EGPO', 'Stornoway Airport', NULL, 'GB', 'Scotland', 58.2156000, -6.3311100, 'active', '2026-01-31 19:22:36', '2026-01-31 19:22:36'),
(3275, 'TRE', 'EGPU', 'Tiree Airport', NULL, 'GB', 'Scotland', 56.4992000, -6.8691700, 'active', '2026-01-31 19:22:36', '2026-01-31 19:22:36'),
(3276, 'UNT', 'EGPW', 'Baltasound Airport', NULL, 'GB', 'Scotland', 60.7469000, -0.8547220, 'active', '2026-01-31 19:22:37', '2026-01-31 19:22:37'),
(3277, 'WHS', 'EGEH', 'Whalsay Airstrip', NULL, 'GB', 'Scotland', 60.3775000, -0.9255560, 'active', '2026-01-31 19:22:37', '2026-01-31 19:22:37'),
(3278, 'WIC', 'EGPC', 'Wick Airport', NULL, 'GB', 'Scotland', 58.4589000, -3.0930600, 'active', '2026-01-31 19:22:37', '2026-01-31 19:22:37'),
(3279, 'WRY', 'EGEW', 'Westray Airport', NULL, 'GB', 'Scotland', 59.3503000, -2.9500000, 'active', '2026-01-31 19:22:38', '2026-01-31 19:22:38'),
(3280, 'FZO', 'EGTG', 'Bristol Filton Airport', NULL, 'GB', 'South Gloucestershire', 51.5194000, -2.5936100, 'active', '2026-01-31 19:22:38', '2026-01-31 19:22:38'),
(3281, 'CEG', 'EGNR', 'Hawarden Airport (Chester Airport)', NULL, 'GB', 'Wales', 53.1781000, -2.9777800, 'active', '2026-01-31 19:22:38', '2026-01-31 19:22:38'),
(3282, 'CWL', 'EGFF', 'Cardiff Airport', NULL, 'GB', 'Wales', 51.3967000, -3.3433300, 'active', '2026-01-31 19:22:39', '2026-01-31 19:22:39'),
(3283, 'HAW', 'EGFE', 'Haverfordwest Aerodrome', NULL, 'GB', 'Wales', 51.8331000, -4.9611100, 'active', '2026-01-31 19:22:39', '2026-01-31 19:22:39'),
(3284, 'SWS', 'EGFH', 'Swansea Airport', NULL, 'GB', 'Wales', 51.6053000, -4.0678300, 'active', '2026-01-31 19:22:39', '2026-01-31 19:22:39'),
(3285, 'VLY', 'EGOV', 'Anglesey Airport / RAF Valley', NULL, 'GB', 'Wales', 53.2481000, -4.5353400, 'active', '2026-01-31 19:22:40', '2026-01-31 19:22:40'),
(3286, 'ESH', 'EGKA', 'Brighton City Airport', NULL, 'GB', 'West Sussex', 50.8356000, -0.2972220, 'active', '2026-01-31 19:22:40', '2026-01-31 19:22:40'),
(3287, 'GND', 'TGPY', 'Maurice Bishop International Airport', NULL, 'GD', 'Saint George', 12.0042000, -61.7862000, 'active', '2026-01-31 19:22:40', '2026-01-31 19:22:40'),
(3288, 'CRU', NULL, 'Lauriston Airport (Carriacou Island Airport)', NULL, 'GD', 'Southern Grenadine Islands', 12.4761000, -61.4728000, 'active', '2026-01-31 19:22:41', '2026-01-31 19:22:41'),
(3289, 'SUI', 'UGSS', 'Sukhumi Babushara Airport (Dranda Airport)', NULL, 'GE', 'Abkhazia', 42.8582000, 41.1281000, 'active', '2026-01-31 19:22:41', '2026-01-31 19:22:41'),
(3290, 'BUS', 'UGSB', 'Batumi International Airport (Alexander Kartveli Batumi Int\'l Airport)', NULL, 'GE', 'Ajaria', 41.6103000, 41.5997000, 'active', '2026-01-31 19:22:41', '2026-01-31 19:22:41'),
(3291, 'KUT', 'UGKO', 'David the Builder Kutaisi International Airport', NULL, 'GE', 'Imereti', 42.1767000, 42.4826000, 'active', '2026-01-31 19:22:42', '2026-01-31 19:22:42'),
(3292, 'TBS', 'UGTB', 'Tbilisi International Airport', NULL, 'GE', 'Tbilisi', 41.6692000, 44.9547000, 'active', '2026-01-31 19:22:42', '2026-01-31 19:22:42'),
(3293, 'CAY', 'SOCA', 'Cayenne - Felix Eboue Airport', NULL, 'GF', 'Guyane', 4.8198100, -52.3604000, 'active', '2026-01-31 19:22:42', '2026-01-31 19:22:42'),
(3294, 'GSI', 'SOGS', 'Grand-Santi Airport', NULL, 'GF', 'Guyane', 4.2858300, -54.3731000, 'active', '2026-01-31 19:22:43', '2026-01-31 19:22:43'),
(3295, 'LDX', 'SOOM', 'Saint-Laurent-du-Maroni Airport', NULL, 'GF', 'Guyane', 5.4830600, -54.0344000, 'active', '2026-01-31 19:22:43', '2026-01-31 19:22:43'),
(3296, 'MPY', 'SOOA', 'Maripasoula Airport', NULL, 'GF', 'Guyane', 3.6575000, -54.0372000, 'active', '2026-01-31 19:22:43', '2026-01-31 19:22:43'),
(3297, 'OYP', 'SOOG', 'Saint-Georges-de-l\'Oyapock Airport', NULL, 'GF', 'Guyane', 3.8976000, -51.8041000, 'active', '2026-01-31 19:22:44', '2026-01-31 19:22:44'),
(3298, 'REI', 'SOOR', 'Regina Airport', NULL, 'GF', 'Guyane', 4.3147200, -52.1317000, 'active', '2026-01-31 19:22:44', '2026-01-31 19:22:44'),
(3299, 'XAU', 'SOOS', 'Saul Airport', NULL, 'GF', 'Guyane', 3.6136100, -53.2042000, 'active', '2026-01-31 19:22:45', '2026-01-31 19:22:45'),
(3300, 'KMS', 'DGSI', 'Kumasi Airport', NULL, 'GH', 'Ashanti', 6.7145600, -1.5908200, 'active', '2026-01-31 19:22:45', '2026-01-31 19:22:45'),
(3301, 'NYI', 'DGSN', 'Sunyani Airport', NULL, 'GH', 'Brong-Ahafo', 7.3618300, -2.3287600, 'active', '2026-01-31 19:22:45', '2026-01-31 19:22:45'),
(3302, 'ACC', 'DGAA', 'Kotoka International Airport', NULL, 'GH', 'Greater Accra', 5.6051900, -0.1667860, 'active', '2026-01-31 19:22:46', '2026-01-31 19:22:46'),
(3303, 'TML', 'DGLE', 'Tamale Airport', NULL, 'GH', 'Northern', 9.5571900, -0.8632140, 'active', '2026-01-31 19:22:46', '2026-01-31 19:22:46'),
(3304, 'WZA', 'DGLW', 'Wa Airport', NULL, 'GH', 'Upper West', 10.0795000, -2.5109000, 'active', '2026-01-31 19:22:46', '2026-01-31 19:22:46'),
(3305, 'TKD', 'DGTK', 'Takoradi Airport', NULL, 'GH', 'Western', 4.8960600, -1.7747600, 'active', '2026-01-31 19:22:47', '2026-01-31 19:22:47'),
(3306, 'GIB', 'LXGB', 'Gibraltar International Airport (North Front Airport)', NULL, 'GI', 'Gibraltar', 36.1512000, -5.3496600, 'active', '2026-01-31 19:22:47', '2026-01-31 19:22:47'),
(3307, 'AOQ', NULL, 'Aappilattoq Heliport', NULL, 'GL', 'Avannaata Kommunia', 72.8870000, -55.5961000, 'active', '2026-01-31 19:22:47', '2026-01-31 19:22:47'),
(3308, 'IKE', NULL, 'Ikerasak Heliport', NULL, 'GL', 'Avannaata Kommunia', 70.4981000, -51.3031000, 'active', '2026-01-31 19:22:48', '2026-01-31 19:22:48'),
(3309, 'IUI', NULL, 'Innarsuit Heliport', NULL, 'GL', 'Avannaata Kommunia', 73.2023000, -56.0113000, 'active', '2026-01-31 19:22:48', '2026-01-31 19:22:48'),
(3310, 'JAV', 'BGJN', 'Ilulissat Airport', NULL, 'GL', 'Avannaata Kommunia', 69.2432000, -51.0571000, 'active', '2026-01-31 19:22:48', '2026-01-31 19:22:48'),
(3311, 'JGO', NULL, 'Qeqertarsuaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 69.2511000, -53.5153000, 'active', '2026-01-31 19:22:49', '2026-01-31 19:22:49'),
(3312, 'JQA', 'BGUQ', 'Qaarsut Airport (Uummannaq/Qaarsut Airport)', NULL, 'GL', 'Avannaata Kommunia', 70.7342000, -52.6962000, 'active', '2026-01-31 19:22:49', '2026-01-31 19:22:49'),
(3313, 'JUK', NULL, 'Ukussissat Heliport', NULL, 'GL', 'Avannaata Kommunia', 71.0512000, -51.8842000, 'active', '2026-01-31 19:22:49', '2026-01-31 19:22:49'),
(3314, 'JUV', 'BGUK', 'Upernavik Airport', NULL, 'GL', 'Avannaata Kommunia', 72.7902000, -56.1306000, 'active', '2026-01-31 19:22:50', '2026-01-31 19:22:50'),
(3315, 'KGQ', NULL, 'Kangersuatsiaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 72.3811000, -55.5363000, 'active', '2026-01-31 19:22:50', '2026-01-31 19:22:50'),
(3316, 'KHQ', NULL, 'Kullorsuaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 74.5791000, -57.2351000, 'active', '2026-01-31 19:22:50', '2026-01-31 19:22:50'),
(3317, 'NAQ', 'BGQQ', 'Qaanaaq Airport', NULL, 'GL', 'Avannaata Kommunia', 77.4886000, -69.3887000, 'active', '2026-01-31 19:22:51', '2026-01-31 19:22:51'),
(3318, 'NIQ', NULL, 'Niaqornat Heliport', NULL, 'GL', 'Avannaata Kommunia', 70.7896000, -53.6562000, 'active', '2026-01-31 19:22:51', '2026-01-31 19:22:51'),
(3319, 'NSQ', NULL, 'Nussuaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 74.1095000, -57.0644000, 'active', '2026-01-31 19:22:51', '2026-01-31 19:22:51'),
(3320, 'PQT', NULL, 'Qeqertaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 69.9994000, -51.3039000, 'active', '2026-01-31 19:22:52', '2026-01-31 19:22:52'),
(3321, 'QUP', NULL, 'Saqqaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 70.0115000, -51.9322000, 'active', '2026-01-31 19:22:52', '2026-01-31 19:22:52'),
(3322, 'SAE', NULL, 'Saattut Keliport', NULL, 'GL', 'Avannaata Kommunia', 70.8071000, -51.6303000, 'active', '2026-01-31 19:22:53', '2026-01-31 19:22:53'),
(3323, 'SRK', NULL, 'Siorapaluk Heliport', NULL, 'GL', 'Avannaata Kommunia', 77.7864000, -70.6384000, 'active', '2026-01-31 19:22:53', '2026-01-31 19:22:53'),
(3324, 'SVR', NULL, 'Savissivik Heliport', NULL, 'GL', 'Avannaata Kommunia', 76.0180000, -65.1176000, 'active', '2026-01-31 19:22:53', '2026-01-31 19:22:53'),
(3325, 'THU', 'BGTL', 'Pituffik Space Base', NULL, 'GL', 'Avannaata Kommunia', 76.5312000, -68.7032000, 'active', '2026-01-31 19:22:54', '2026-01-31 19:22:54'),
(3326, 'TQA', NULL, 'Tasiusaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 73.3735000, -56.0620000, 'active', '2026-01-31 19:22:54', '2026-01-31 19:22:54'),
(3327, 'UMD', 'BGUM', 'Uummannaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 70.6804000, -52.1116000, 'active', '2026-01-31 19:22:54', '2026-01-31 19:22:54'),
(3328, 'UPK', NULL, 'Upernavik Kujalleq Heliport', NULL, 'GL', 'Avannaata Kommunia', 72.1527000, -55.5310000, 'active', '2026-01-31 19:22:55', '2026-01-31 19:22:55'),
(3329, 'XIQ', NULL, 'Ilimanaq Heliport', NULL, 'GL', 'Avannaata Kommunia', 69.0822000, -51.1088000, 'active', '2026-01-31 19:22:56', '2026-01-31 19:22:56'),
(3330, 'JJU', NULL, 'Mittarfik Qaqortoq Heliport', NULL, 'GL', 'Kommune Kujalleq', 60.7156000, -46.0299000, 'active', '2026-01-31 19:22:56', '2026-01-31 19:22:56'),
(3331, 'JNN', NULL, 'Nanortalik Heliport', NULL, 'GL', 'Kommune Kujalleq', 60.1418000, -45.2330000, 'active', '2026-01-31 19:22:56', '2026-01-31 19:22:56'),
(3332, 'JNS', NULL, 'Narsaq Heliport', NULL, 'GL', 'Kommune Kujalleq', 60.9172000, -46.0600000, 'active', '2026-01-31 19:22:57', '2026-01-31 19:22:57'),
(3333, 'LLU', NULL, 'Alluitsup Paa Heliport', NULL, 'GL', 'Kommune Kujalleq', 60.4645000, -45.5691000, 'active', '2026-01-31 19:22:57', '2026-01-31 19:22:57'),
(3334, 'QFN', NULL, 'Narsaq Kujalleq Narsarmijit Heliport', NULL, 'GL', 'Kommune Kujalleq', 60.0051000, -44.6579000, 'active', '2026-01-31 19:22:57', '2026-01-31 19:22:57'),
(3335, 'QUV', NULL, 'Aappilattoq-Nanortaliq Heliport', NULL, 'GL', 'Kommune Kujalleq', 60.1483000, -44.2869000, 'active', '2026-01-31 19:22:58', '2026-01-31 19:22:58'),
(3336, 'QUW', NULL, 'Ammassivik Heliport', NULL, 'GL', 'Kommune Kujalleq', 60.5953000, -45.3820000, 'active', '2026-01-31 19:22:58', '2026-01-31 19:22:58'),
(3337, 'UAK', 'BGBW', 'Narsarsuaq Airport', NULL, 'GL', 'Kommune Kujalleq', 61.1605000, -45.4260000, 'active', '2026-01-31 19:22:58', '2026-01-31 19:22:58'),
(3338, 'XEQ', NULL, 'Tasiusaq Heliport', NULL, 'GL', 'Kommune Kujalleq', 60.1937000, -44.8115000, 'active', '2026-01-31 19:22:59', '2026-01-31 19:22:59'),
(3339, 'JCH', 'BGCH', 'Qasigiannguit Heliport', NULL, 'GL', 'Kommune Qeqertalik', 68.8228000, -51.1734000, 'active', '2026-01-31 19:22:59', '2026-01-31 19:22:59'),
(3340, 'JEG', 'BGAA', 'Aasiaat Airport', NULL, 'GL', 'Kommune Qeqertalik', 68.7218000, -52.7847000, 'active', '2026-01-31 19:22:59', '2026-01-31 19:22:59'),
(3341, 'QCU', NULL, 'Akunnaaq Heliport', NULL, 'GL', 'Kommune Qeqertalik', 68.7441000, -52.3290000, 'active', '2026-01-31 19:23:00', '2026-01-31 19:23:00'),
(3342, 'QFI', NULL, 'Iginniarfik Heliport', NULL, 'GL', 'Kommune Qeqertalik', 68.1458000, -53.1692000, 'active', '2026-01-31 19:23:00', '2026-01-31 19:23:00'),
(3343, 'QGQ', NULL, 'Attu Heliport', NULL, 'GL', 'Kommune Qeqertalik', 67.9430000, -53.6223000, 'active', '2026-01-31 19:23:00', '2026-01-31 19:23:00'),
(3344, 'QJE', NULL, 'Kitsissuarsuit Heliport', NULL, 'GL', 'Kommune Qeqertalik', 68.8558000, -53.1185000, 'active', '2026-01-31 19:23:01', '2026-01-31 19:23:01'),
(3345, 'QJI', NULL, 'Ikamiut Heliport', NULL, 'GL', 'Kommune Qeqertalik', 68.6321000, -51.8337000, 'active', '2026-01-31 19:23:01', '2026-01-31 19:23:01'),
(3346, 'QMK', NULL, 'Niaqornaarsuk Heliport', NULL, 'GL', 'Kommune Qeqertalik', 68.2342000, -52.8546000, 'active', '2026-01-31 19:23:01', '2026-01-31 19:23:01'),
(3347, 'QPW', NULL, 'Kangaatsiaq Heliport', NULL, 'GL', 'Kommune Qeqertalik', 68.3079000, -53.4592000, 'active', '2026-01-31 19:23:02', '2026-01-31 19:23:02'),
(3348, 'QRY', NULL, 'Ikerasaarsuk Heliport', NULL, 'GL', 'Kommune Qeqertalik', 68.1409000, -53.4414000, 'active', '2026-01-31 19:23:02', '2026-01-31 19:23:02'),
(3349, 'AGM', NULL, 'Tasiilaq Heliport', NULL, 'GL', 'Kommunegarfik Sermersooq', 65.6122000, -37.6184000, 'active', '2026-01-31 19:23:02', '2026-01-31 19:23:02'),
(3350, 'CNP', 'BGCO', 'Nerlerit Inaat Airport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 70.7431000, -22.6505000, 'active', '2026-01-31 19:23:03', '2026-01-31 19:23:03'),
(3351, 'GOH', 'BGGH', 'Nuuk Airport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 64.1909000, -51.6781000, 'active', '2026-01-31 19:23:03', '2026-01-31 19:23:03'),
(3352, 'IOQ', NULL, 'Isortoq Heliport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 65.5465000, -38.9778000, 'active', '2026-01-31 19:23:03', '2026-01-31 19:23:03'),
(3353, 'JFR', 'BGPT', 'Paamiut Airport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 62.0147000, -49.6709000, 'active', '2026-01-31 19:23:04', '2026-01-31 19:23:04'),
(3354, 'JRK', NULL, 'Arsuk Heliport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 61.1768000, -48.4198000, 'active', '2026-01-31 19:23:04', '2026-01-31 19:23:04'),
(3355, 'KUS', 'BGKK', 'Kulusuk Airport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 65.5736000, -37.1236000, 'active', '2026-01-31 19:23:04', '2026-01-31 19:23:04'),
(3356, 'KUZ', NULL, 'Kuummiit Heliport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 65.8638000, -36.9954000, 'active', '2026-01-31 19:23:05', '2026-01-31 19:23:05'),
(3357, 'OBY', NULL, 'Ittoqqortoormiit Heliport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 70.4881000, -21.9716000, 'active', '2026-01-31 19:23:05', '2026-01-31 19:23:05'),
(3358, 'SGG', NULL, 'Sermiligaaq Heliport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 65.9059000, -36.3781000, 'active', '2026-01-31 19:23:05', '2026-01-31 19:23:05'),
(3359, 'TQI', NULL, 'Tiniteqilaaq Heliport', NULL, 'GL', 'Kommuneqarfik Sermersooq', 65.8920000, -37.7833000, 'active', '2026-01-31 19:23:06', '2026-01-31 19:23:06'),
(3360, 'JHS', 'BGSS', 'Sisimiut Airport', NULL, 'GL', 'Qeqqata Kommunia', 66.9513000, -53.7293000, 'active', '2026-01-31 19:23:06', '2026-01-31 19:23:06'),
(3361, 'JSU', 'BGMQ', 'Maniitsoq Airport', NULL, 'GL', 'Qeqqata Kommunia', 65.4125000, -52.9394000, 'active', '2026-01-31 19:23:06', '2026-01-31 19:23:06'),
(3362, 'QJG', NULL, 'Itilleq Heliport', NULL, 'GL', 'Qeqqata Kommunia', 66.5791000, -53.5014000, 'active', '2026-01-31 19:23:07', '2026-01-31 19:23:07'),
(3363, 'SFJ', 'BGSF', 'Kangerlussuaq Airport', NULL, 'GL', 'Qeqqata Kommunia', 67.0122000, -50.7116000, 'active', '2026-01-31 19:23:07', '2026-01-31 19:23:07'),
(3364, 'SZC', NULL, 'Sarfannguit Heliport', NULL, 'GL', 'Qeqqata Kommunia', 66.8964000, -52.8657000, 'active', '2026-01-31 19:23:07', '2026-01-31 19:23:07'),
(3365, 'BJL', 'GBYD', 'Banjul International Airport', NULL, 'GM', 'Banjul', 13.3380000, -16.6522000, 'active', '2026-01-31 19:23:08', '2026-01-31 19:23:08'),
(3366, 'BKJ', 'GUOK', 'Boke Baralande Airport', NULL, 'GN', 'Boke', 10.9658000, -14.2811000, 'active', '2026-01-31 19:23:08', '2026-01-31 19:23:08'),
(3367, 'SBI', 'GUSB', 'Sambailo Airport', NULL, 'GN', 'Boke', 12.5727000, -13.3585000, 'active', '2026-01-31 19:23:08', '2026-01-31 19:23:08'),
(3368, 'CKY', 'GUCY', 'Ahmed Sékou Touré International Airport', NULL, 'GN', 'Conakry', 9.5768900, -13.6120000, 'active', '2026-01-31 19:23:09', '2026-01-31 19:23:09'),
(3369, 'FAA', 'GUFH', 'Faranah Airport', NULL, 'GN', 'Faranah', 10.0355000, -10.7698000, 'active', '2026-01-31 19:23:09', '2026-01-31 19:23:09'),
(3370, 'FIG', 'GUFA', 'Fria Airport', NULL, 'GN', 'Faranah', 10.3506000, -13.5692000, 'active', '2026-01-31 19:23:09', '2026-01-31 19:23:09'),
(3371, 'GII', 'GUSI', 'Siguiri Airport', NULL, 'GN', 'Kankan', 11.4330000, -9.1670000, 'active', '2026-01-31 19:23:10', '2026-01-31 19:23:10'),
(3372, 'KNN', 'GUXN', 'Kankan Airport (Diankana Airport)', NULL, 'GN', 'Kankan', 10.4484000, -9.2287600, 'active', '2026-01-31 19:23:10', '2026-01-31 19:23:10'),
(3373, 'KSI', 'GUKU', 'Kissidougou Airport', NULL, 'GN', 'Labe', 9.1605600, -10.1244000, 'active', '2026-01-31 19:23:11', '2026-01-31 19:23:11'),
(3374, 'LEK', 'GULB', 'Tata Airport', NULL, 'GN', 'Labe', 11.3261000, -12.2868000, 'active', '2026-01-31 19:23:11', '2026-01-31 19:23:11'),
(3375, 'MCA', 'GUMA', 'Macenta Airport', NULL, 'GN', 'Nzerekore', 8.4818600, -9.5250700, 'active', '2026-01-31 19:23:11', '2026-01-31 19:23:11'),
(3376, 'NZE', 'GUNZ', 'Nzerekore Airport', NULL, 'GN', 'Nzerekore', 7.8060200, -8.7018000, 'active', '2026-01-31 19:23:12', '2026-01-31 19:23:12'),
(3377, 'BBR', 'TFFB', 'Baillif Airport', NULL, 'GP', 'Guadeloupe', 16.0133000, -61.7422000, 'active', '2026-01-31 19:23:12', '2026-01-31 19:23:12'),
(3378, 'DSD', 'TFFA', 'La Desirade Airport (Grande-Anse Airport)', NULL, 'GP', 'Guadeloupe', 16.2969000, -61.0844000, 'active', '2026-01-31 19:23:12', '2026-01-31 19:23:12'),
(3379, 'GBJ', 'TFFM', 'Marie-Galante Airport (Les Bases)', NULL, 'GP', 'Guadeloupe', 15.8687000, -61.2700000, 'active', '2026-01-31 19:23:13', '2026-01-31 19:23:13'),
(3380, 'LSS', 'TFFS', 'Les Saintes Airport', NULL, 'GP', 'Guadeloupe', 15.8644000, -61.5806000, 'active', '2026-01-31 19:23:13', '2026-01-31 19:23:13'),
(3381, 'PTP', 'TFFR', 'Pointe-a-Pitre International Airport (Le Raizet Airport)', NULL, 'GP', 'Guadeloupe', 16.2653000, -61.5318000, 'active', '2026-01-31 19:23:13', '2026-01-31 19:23:13'),
(3382, 'SFC', 'TFFC', 'Saint-Francois Airport', NULL, 'GP', 'Guadeloupe', 16.2578000, -61.2625000, 'active', '2026-01-31 19:23:14', '2026-01-31 19:23:14'),
(3383, 'NBN', 'FGAB', 'Annobon Air', NULL, 'GQ', 'Annobon', -1.4102800, 5.6219400, 'active', '2026-01-31 19:23:14', '2026-01-31 19:23:14'),
(3384, 'SSG', 'FGSL', 'Malabo International Airport (Saint Isabel Airport)', NULL, 'GQ', 'Bioko Norte', 3.7552700, 8.7087200, 'active', '2026-01-31 19:23:14', '2026-01-31 19:23:14'),
(3385, 'BSG', 'FGBT', 'Bata Airport', NULL, 'GQ', 'Litoral', 1.9054700, 9.8056800, 'active', '2026-01-31 19:23:15', '2026-01-31 19:23:15'),
(3386, 'OCS', NULL, 'Corisco International Airport', NULL, 'GQ', 'Litoral', 0.9125000, 9.3304000, 'active', '2026-01-31 19:23:15', '2026-01-31 19:23:15'),
(3387, 'GEM', 'FGMY', 'President Obiang Nguema International Airport', NULL, 'GQ', 'Wele-Nzas', 1.6853300, 11.0244000, 'active', '2026-01-31 19:23:15', '2026-01-31 19:23:15'),
(3388, 'AXD', 'LGAL', 'Alexandroupoli Airport (Dimokritos Airport)', NULL, 'GR', 'Anatoliki Makedonia kai Thraki', 40.8559000, 25.9563000, 'active', '2026-01-31 19:23:16', '2026-01-31 19:23:16'),
(3389, 'KVA', 'LGKV', 'Kavala International Airport (Alexander the Great Airport)', NULL, 'GR', 'Anatoliki Makedonia kai Thraki', 40.9133000, 24.6192000, 'active', '2026-01-31 19:23:16', '2026-01-31 19:23:16'),
(3390, 'ATH', 'LGAV', 'Athens International Airport (Eleftherios Venizelos Airport)', NULL, 'GR', 'Attiki', 37.9364000, 23.9445000, 'active', '2026-01-31 19:23:16', '2026-01-31 19:23:16'),
(3391, 'KIT', 'LGKC', 'Kithira Island National Airport', NULL, 'GR', 'Attiki', 36.2743000, 23.0170000, 'active', '2026-01-31 19:23:17', '2026-01-31 19:23:17'),
(3392, 'AGQ', 'LGAG', 'Agrinion Airport', NULL, 'GR', 'Dytiki Ellada', 38.6020000, 21.3512000, 'active', '2026-01-31 19:23:17', '2026-01-31 19:23:17'),
(3393, 'GPA', 'LGRX', 'Araxos Airport', NULL, 'GR', 'Dytiki Ellada', 38.1511000, 21.4256000, 'active', '2026-01-31 19:23:17', '2026-01-31 19:23:17'),
(3394, 'PYR', 'LGAD', 'Andravida Air Base', NULL, 'GR', 'Dytiki Ellada', 37.9207000, 21.2926000, 'active', '2026-01-31 19:23:18', '2026-01-31 19:23:18'),
(3395, 'KSO', 'LGKA', 'Kastoria National Airport (Aristotelis Airport)', NULL, 'GR', 'Dytiki Makedonia', 40.4463000, 21.2822000, 'active', '2026-01-31 19:23:18', '2026-01-31 19:23:18'),
(3396, 'KZI', 'LGKZ', 'Kozani National Airport (Filippos Airport)', NULL, 'GR', 'Dytiki Makedonia', 40.2861000, 21.8408000, 'active', '2026-01-31 19:23:19', '2026-01-31 19:23:19'),
(3397, 'CFU', 'LGKR', 'Corfu International Airport (Ioannis Kapodistrias Int\'l Airport)', NULL, 'GR', 'Ionia Nisia', 39.6019000, 19.9117000, 'active', '2026-01-31 19:23:19', '2026-01-31 19:23:19'),
(3398, 'EFL', 'LGKF', 'Kefalonia International Airport', NULL, 'GR', 'Ionia Nisia', 38.1201000, 20.5005000, 'active', '2026-01-31 19:23:19', '2026-01-31 19:23:19'),
(3399, 'PVK', 'LGPZ', 'Aktion National Airport', NULL, 'GR', 'Ionia Nisia', 38.9255000, 20.7653000, 'active', '2026-01-31 19:23:20', '2026-01-31 19:23:20'),
(3400, 'ZTH', 'LGZA', 'Zakynthos International Airport (Dionysios SolomosAirport)', NULL, 'GR', 'Ionia Nisia', 37.7509000, 20.8843000, 'active', '2026-01-31 19:23:20', '2026-01-31 19:23:20'),
(3401, 'IOA', 'LGIO', 'Ioannina National Airport', NULL, 'GR', 'Ipeiros', 39.6964000, 20.8225000, 'active', '2026-01-31 19:23:20', '2026-01-31 19:23:20'),
(3402, 'SKG', 'LGTS', 'Thessaloniki Airport', NULL, 'GR', 'Kentriki Makedonia', 40.5197000, 22.9709000, 'active', '2026-01-31 19:23:21', '2026-01-31 19:23:21'),
(3403, 'CHQ', 'LGSA', 'Chania International Airport', NULL, 'GR', 'Kriti', 35.5317000, 24.1497000, 'active', '2026-01-31 19:23:21', '2026-01-31 19:23:21'),
(3404, 'HER', 'LGIR', 'Heraklion International Airport (Nikos Kazantzakis Airport)', NULL, 'GR', 'Kriti', 35.3397000, 25.1803000, 'active', '2026-01-31 19:23:21', '2026-01-31 19:23:21'),
(3405, 'JSH', 'LGST', 'Sitia Public Airport', NULL, 'GR', 'Kriti', 35.2161000, 26.1013000, 'active', '2026-01-31 19:23:22', '2026-01-31 19:23:22'),
(3406, 'AOK', 'LGKP', 'Karpathos Island National Airport', NULL, 'GR', 'Notio Aigaio', 35.4214000, 27.1460000, 'active', '2026-01-31 19:23:22', '2026-01-31 19:23:22'),
(3407, 'JKL', 'LGKY', 'Kalymnos Island National Airport', NULL, 'GR', 'Notio Aigaio', 36.9633000, 26.9406000, 'active', '2026-01-31 19:23:22', '2026-01-31 19:23:22'),
(3408, 'JMK', 'LGMK', 'Mykonos Island National Airport', NULL, 'GR', 'Notio Aigaio', 37.4351000, 25.3481000, 'active', '2026-01-31 19:23:23', '2026-01-31 19:23:23'),
(3409, 'JNX', 'LGNX', 'Naxos Island National Airport', NULL, 'GR', 'Notio Aigaio', 37.0811000, 25.3681000, 'active', '2026-01-31 19:23:23', '2026-01-31 19:23:23'),
(3410, 'JSY', 'LGSO', 'Syros Island National Airport', NULL, 'GR', 'Notio Aigaio', 37.4228000, 24.9509000, 'active', '2026-01-31 19:23:23', '2026-01-31 19:23:23'),
(3411, 'JTR', 'LGSR', 'Santorini (Thira) National Airport', NULL, 'GR', 'Notio Aigaio', 36.3992000, 25.4793000, 'active', '2026-01-31 19:23:24', '2026-01-31 19:23:24'),
(3412, 'JTY', 'LGPL', 'Astypalaia Island National Airport', NULL, 'GR', 'Notio Aigaio', 36.5799000, 26.3758000, 'active', '2026-01-31 19:23:25', '2026-01-31 19:23:25'),
(3413, 'KGS', 'LGKO', 'Kos Island International Airport', NULL, 'GR', 'Notio Aigaio', 36.7933000, 27.0917000, 'active', '2026-01-31 19:23:26', '2026-01-31 19:23:26'),
(3414, 'KSJ', 'LGKS', 'Kasos Island Public Airport', NULL, 'GR', 'Notio Aigaio', 35.4214000, 26.9100000, 'active', '2026-01-31 19:23:26', '2026-01-31 19:23:26'),
(3415, 'KZS', 'LGKJ', 'Kastellorizo Island Public Airport', NULL, 'GR', 'Notio Aigaio', 36.1417000, 29.5764000, 'active', '2026-01-31 19:23:26', '2026-01-31 19:23:26'),
(3416, 'LRS', 'LGLE', 'Leros Municipal Airport', NULL, 'GR', 'Notio Aigaio', 37.1849000, 26.8003000, 'active', '2026-01-31 19:23:27', '2026-01-31 19:23:27'),
(3417, 'MLO', 'LGML', 'Milos Island National Airport', NULL, 'GR', 'Notio Aigaio', 36.6969000, 24.4769000, 'active', '2026-01-31 19:23:27', '2026-01-31 19:23:27'),
(3418, 'PAS', 'LGPA', 'Paros National Airport', NULL, 'GR', 'Notio Aigaio', 37.0205000, 25.1132000, 'active', '2026-01-31 19:23:27', '2026-01-31 19:23:27'),
(3419, 'RHO', 'LGRP', 'Rhodes International Airport', NULL, 'GR', 'Notio Aigaio', 36.4054000, 28.0862000, 'active', '2026-01-31 19:23:28', '2026-01-31 19:23:28'),
(3420, 'PKH', 'LGHL', 'Porto Cheli Airport', NULL, 'GR', 'Peloponnese', 37.2988000, 23.1490000, 'active', '2026-01-31 19:23:28', '2026-01-31 19:23:28'),
(3421, 'KLX', 'LGKL', 'Kalamata International Airport', NULL, 'GR', 'Peloponnisos', 37.0683000, 22.0255000, 'active', '2026-01-31 19:23:28', '2026-01-31 19:23:28'),
(3422, 'SPJ', 'LGSP', 'Sparti Airport', NULL, 'GR', 'Peloponnisos', 36.9739000, 22.5263000, 'active', '2026-01-31 19:23:29', '2026-01-31 19:23:29'),
(3423, 'SKU', 'LGSY', 'Skyros Island National Airport', NULL, 'GR', 'Sterea Ellada', 38.9676000, 24.4872000, 'active', '2026-01-31 19:23:29', '2026-01-31 19:23:29'),
(3424, 'JSI', 'LGSK', 'Skiathos Island National Airport', NULL, 'GR', 'Thessalia', 39.1771000, 23.5037000, 'active', '2026-01-31 19:23:29', '2026-01-31 19:23:29'),
(3425, 'LRA', 'LGLR', 'Larissa National Airport', NULL, 'GR', 'Thessalia', 39.6503000, 22.4655000, 'active', '2026-01-31 19:23:30', '2026-01-31 19:23:30'),
(3426, 'VOL', 'LGBL', 'Nea Anchialos National Airport', NULL, 'GR', 'Thessalia', 39.2196000, 22.7943000, 'active', '2026-01-31 19:23:30', '2026-01-31 19:23:30'),
(3427, 'JIK', 'LGIK', 'Ikaria Island National Airport', NULL, 'GR', 'Voreio Aigaio', 37.6827000, 26.3471000, 'active', '2026-01-31 19:23:30', '2026-01-31 19:23:30'),
(3428, 'JKH', 'LGHI', 'Chios Island National Airport', NULL, 'GR', 'Voreio Aigaio', 38.3432000, 26.1406000, 'active', '2026-01-31 19:23:31', '2026-01-31 19:23:31'),
(3429, 'LXS', 'LGLM', 'Lemnos International Airport', NULL, 'GR', 'Voreio Aigaio', 39.9171000, 25.2363000, 'active', '2026-01-31 19:23:31', '2026-01-31 19:23:31'),
(3430, 'MJT', 'LGMT', 'Mytilene International Airport', NULL, 'GR', 'Voreio Aigaio', 39.0567000, 26.5983000, 'active', '2026-01-31 19:23:31', '2026-01-31 19:23:31'),
(3431, 'SMI', 'LGSM', 'Samos International Airport', NULL, 'GR', 'Voreio Aigaio', 37.6900000, 26.9117000, 'active', '2026-01-31 19:23:32', '2026-01-31 19:23:32'),
(3432, 'CBV', 'MGCB', 'Coban Airport', NULL, 'GT', 'Alta Verapaz', 15.4690000, -90.4067000, 'active', '2026-01-31 19:23:32', '2026-01-31 19:23:32'),
(3433, 'RUV', 'MGRB', 'Rubelsanto Airport', NULL, 'GT', 'Alta Verapaz', 15.9920000, -90.4453000, 'active', '2026-01-31 19:23:32', '2026-01-31 19:23:32'),
(3434, 'CIQ', NULL, 'Chiquimula Airport', NULL, 'GT', 'Chiquimula', 14.8309000, -89.5209000, 'active', '2026-01-31 19:23:33', '2026-01-31 19:23:33'),
(3435, 'ENJ', NULL, 'El Naranjo Airport', NULL, 'GT', 'Escuintla', 14.1069000, -90.8175000, 'active', '2026-01-31 19:23:33', '2026-01-31 19:23:33'),
(3436, 'GSJ', 'MGSJ', 'San Jose Airport', NULL, 'GT', 'Escuintla', 13.9362000, -90.8358000, 'active', '2026-01-31 19:23:33', '2026-01-31 19:23:33'),
(3437, 'GUA', 'MGGT', 'La Aurora International Airport', NULL, 'GT', 'Guatemala', 14.5817000, -90.5267000, 'active', '2026-01-31 19:23:34', '2026-01-31 19:23:34'),
(3438, 'HUG', 'MGHT', 'Huehuetenango Airport', NULL, 'GT', 'Huehuetenango', 15.3274000, -91.4624000, 'active', '2026-01-31 19:23:34', '2026-01-31 19:23:34'),
(3439, 'LCF', 'MGRD', 'Rio Dulce Airport (Las Vegas Airport)', NULL, 'GT', 'Izabal', 15.6684000, -88.9618000, 'active', '2026-01-31 19:23:34', '2026-01-31 19:23:34'),
(3440, 'PBR', 'MGPB', 'Puerto Barrios Airport', NULL, 'GT', 'Izabal', 15.7309000, -88.5838000, 'active', '2026-01-31 19:23:35', '2026-01-31 19:23:35'),
(3441, 'CMM', 'MGCR', 'Carmelita Airport', NULL, 'GT', 'Peten', 17.4612000, -90.0537000, 'active', '2026-01-31 19:23:35', '2026-01-31 19:23:35'),
(3442, 'DON', NULL, 'Dos Lagunas Airport', NULL, 'GT', 'Peten', 17.6124000, -89.6884000, 'active', '2026-01-31 19:23:35', '2026-01-31 19:23:35'),
(3443, 'FRS', 'MGTK', 'Mundo Maya International Airport', NULL, 'GT', 'Peten', 16.9138000, -89.8664000, 'active', '2026-01-31 19:23:36', '2026-01-31 19:23:36'),
(3444, 'PON', 'MGPP', 'Poptun Airport', NULL, 'GT', 'Peten', 16.3258000, -89.4161000, 'active', '2026-01-31 19:23:36', '2026-01-31 19:23:36'),
(3445, 'UAX', NULL, 'Uaxactun Airport', NULL, 'GT', 'Peten', 17.3939000, -89.6327000, 'active', '2026-01-31 19:23:36', '2026-01-31 19:23:36'),
(3446, 'AAZ', 'MGQZ', 'Quetzaltenango Airport', NULL, 'GT', 'Quetzaltenango', 14.8656000, -91.5020000, 'active', '2026-01-31 19:23:37', '2026-01-31 19:23:37'),
(3447, 'CTF', 'MGCT', 'Coatepeque Airport', NULL, 'GT', 'Quetzaltenango', 14.6942000, -91.8825000, 'active', '2026-01-31 19:23:37', '2026-01-31 19:23:37'),
(3448, 'AQB', 'MGQC', 'Quiche Airport', NULL, 'GT', 'Quiche', 15.0122000, -91.1506000, 'active', '2026-01-31 19:23:37', '2026-01-31 19:23:37'),
(3449, 'PKJ', 'MGPG', 'Playa Grande Airport', NULL, 'GT', 'Quiche', 15.9975000, -90.7417000, 'active', '2026-01-31 19:23:38', '2026-01-31 19:23:38'),
(3450, 'RER', 'MGRT', 'Retalhuleu Airport', NULL, 'GT', 'Retalhuleu', 14.5210000, -91.6973000, 'active', '2026-01-31 19:23:38', '2026-01-31 19:23:38'),
(3451, 'LOX', NULL, 'Los Tablones Airport', NULL, 'GT', 'Zacapa', 14.5833000, -90.5275000, 'active', '2026-01-31 19:23:38', '2026-01-31 19:23:38'),
(3452, 'GUM', 'PGUM', 'Antonio B. Won Pat International Airport (Guam Int\'l)', NULL, 'GU', 'Barrigada', 13.4834000, 144.7960000, 'active', '2026-01-31 19:23:39', '2026-01-31 19:23:39'),
(3453, 'UAM', 'PGUA', 'Andersen Air Force Base', NULL, 'GU', 'Yigo', 13.5840000, 144.9300000, 'active', '2026-01-31 19:23:39', '2026-01-31 19:23:39'),
(3454, 'OXB', 'GGOV', 'Osvaldo Vieira International Airport', NULL, 'GW', 'Bissau', 11.8948000, -15.6537000, 'active', '2026-01-31 19:23:40', '2026-01-31 19:23:40'),
(3455, 'BQE', 'GGBU', 'Bubaque Airport', NULL, 'GW', 'Bolama', 11.2974000, -15.8381000, 'active', '2026-01-31 19:23:40', '2026-01-31 19:23:40'),
(3456, 'BCG', NULL, 'Bemichi Airport', NULL, 'GY', 'Barima-Waini', 7.7000000, -59.1667000, 'active', '2026-01-31 19:23:41', '2026-01-31 19:23:41'),
(3457, 'BMJ', 'SYBR', 'Baramita Airport', NULL, 'GY', 'Barima-Waini', 7.3701200, -60.4880000, 'active', '2026-01-31 19:23:41', '2026-01-31 19:23:41'),
(3458, 'MWJ', 'SYMR', 'Matthews Ridge Airport', NULL, 'GY', 'Barima-Waini', 7.4881100, -60.1848000, 'active', '2026-01-31 19:23:41', '2026-01-31 19:23:41'),
(3459, 'PKM', NULL, 'Port Kaituma Airstrip', NULL, 'GY', 'Barima-Waini', 8.3330000, -59.6330000, 'active', '2026-01-31 19:23:42', '2026-01-31 19:23:42'),
(3460, 'USI', 'SYMB', 'Mabaruma Airport', NULL, 'GY', 'Barima-Waini', 8.2000000, -59.7833000, 'active', '2026-01-31 19:23:42', '2026-01-31 19:23:42'),
(3461, 'GFO', 'SYBT', 'Bartica Airport', NULL, 'GY', 'Cuyuni-Mazaruni', 6.3588600, -58.6552000, 'active', '2026-01-31 19:23:42', '2026-01-31 19:23:42'),
(3462, 'IMB', 'SYIB', 'Imbaimadai Airport', NULL, 'GY', 'Cuyuni-Mazaruni', 5.7081100, -60.2942000, 'active', '2026-01-31 19:23:43', '2026-01-31 19:23:43'),
(3463, 'KAR', 'SYKM', 'Kamarang Airport', NULL, 'GY', 'Cuyuni-Mazaruni', 5.8653400, -60.6142000, 'active', '2026-01-31 19:23:43', '2026-01-31 19:23:43'),
(3464, 'KPG', NULL, 'Kurupung Airport', NULL, 'GY', 'Cuyuni-Mazaruni', 6.4666700, -59.1667000, 'active', '2026-01-31 19:23:43', '2026-01-31 19:23:43'),
(3465, 'PRR', 'SYPR', 'Paruima Airport', NULL, 'GY', 'Cuyuni-Mazaruni', 5.8154500, -61.0554000, 'active', '2026-01-31 19:23:44', '2026-01-31 19:23:44'),
(3466, 'GEO', 'SYCJ', 'Cheddi Jagan International Airport', NULL, 'GY', 'Demerara-Mahaica', 6.4985500, -58.2541000, 'active', '2026-01-31 19:23:44', '2026-01-31 19:23:44'),
(3467, 'OGL', 'SYGO', 'Eugene F. Correia International Airport', NULL, 'GY', 'Demerara-Mahaica', 6.8062800, -58.1059000, 'active', '2026-01-31 19:23:44', '2026-01-31 19:23:44'),
(3468, 'SKM', NULL, 'Skeldon Airport', NULL, 'GY', 'East Berbice-Corentyne', 5.8599000, -57.1489000, 'active', '2026-01-31 19:23:45', '2026-01-31 19:23:45'),
(3469, 'EKE', NULL, 'Ekereku Airport', NULL, 'GY', 'Essequibo Islands-West Demerara', 6.6666700, -60.8500000, 'active', '2026-01-31 19:23:45', '2026-01-31 19:23:45'),
(3470, 'KKG', 'SYKZ', 'Konawaruk Airport', NULL, 'GY', 'Essequibo Islands-West Demerara', 5.2684000, -58.9950000, 'active', '2026-01-31 19:23:45', '2026-01-31 19:23:45'),
(3471, 'PIQ', NULL, 'Pipillipai Airport', NULL, 'GY', 'Essequibo Islands-West Demerara', 5.3333300, -60.3333000, 'active', '2026-01-31 19:23:46', '2026-01-31 19:23:46'),
(3472, 'SDC', 'SYSC', 'Sand Creek Airport', NULL, 'GY', 'Essequibo Islands-West Demerara', 2.9913000, -59.5100000, 'active', '2026-01-31 19:23:46', '2026-01-31 19:23:46'),
(3473, 'VEG', 'SYMK', 'Maikwak Airport', NULL, 'GY', 'Essequibo Islands-West Demerara', 4.8981700, -59.8170000, 'active', '2026-01-31 19:23:46', '2026-01-31 19:23:46'),
(3474, 'KAI', 'SYKA', 'Kaieteur International Airport', NULL, 'GY', 'Potaro-Siparuni', 5.1727500, -59.4915000, 'active', '2026-01-31 19:23:47', '2026-01-31 19:23:47'),
(3475, 'KTO', 'SYKT', 'Kato Airport', NULL, 'GY', 'Potaro-Siparuni', 4.6491600, -59.8322000, 'active', '2026-01-31 19:23:47', '2026-01-31 19:23:47'),
(3476, 'MHA', 'SYMD', 'Mahdia Airport', NULL, 'GY', 'Potaro-Siparuni', 5.2774900, -59.1511000, 'active', '2026-01-31 19:23:47', '2026-01-31 19:23:47'),
(3477, 'MYM', 'SYMM', 'Monkey Mountain Airport', NULL, 'GY', 'Potaro-Siparuni', 4.4833300, -59.6833000, 'active', '2026-01-31 19:23:48', '2026-01-31 19:23:48'),
(3478, 'ORJ', 'SYOR', 'Orinduik Airport', NULL, 'GY', 'Potaro-Siparuni', 4.7252700, -60.0350000, 'active', '2026-01-31 19:23:48', '2026-01-31 19:23:48'),
(3479, 'PMT', NULL, 'Paramakatoi Airport', NULL, 'GY', 'Potaro-Siparuni', 4.6975000, -59.7125000, 'active', '2026-01-31 19:23:48', '2026-01-31 19:23:48'),
(3480, 'AHL', 'SYAH', 'Aishalton Airport', NULL, 'GY', 'Upper Takutu-Upper Essequibo', 2.4865300, -59.3134000, 'active', '2026-01-31 19:23:49', '2026-01-31 19:23:49'),
(3481, 'KRG', 'SYKS', 'Karasabai Airport', NULL, 'GY', 'Upper Takutu-Upper Essequibo', 4.0333300, -59.5333000, 'active', '2026-01-31 19:23:49', '2026-01-31 19:23:49'),
(3482, 'KRM', 'SYKR', 'Karanambo Airport', NULL, 'GY', 'Upper Takutu-Upper Essequibo', 3.7519400, -59.3097000, 'active', '2026-01-31 19:23:49', '2026-01-31 19:23:49'),
(3483, 'LTM', 'SYLT', 'Lethem Airport', NULL, 'GY', 'Upper Takutu-Upper Essequibo', 3.3727600, -59.7894000, 'active', '2026-01-31 19:23:50', '2026-01-31 19:23:50'),
(3484, 'LUB', 'SYLP', 'Lumid Pau Airport', NULL, 'GY', 'Upper Takutu-Upper Essequibo', 2.3939300, -59.4410000, 'active', '2026-01-31 19:23:50', '2026-01-31 19:23:50'),
(3485, 'NAI', 'SYAN', 'Annai Airport', NULL, 'GY', 'Upper Takutu-Upper Essequibo', 3.9594400, -59.1242000, 'active', '2026-01-31 19:23:51', '2026-01-31 19:23:51'),
(3486, 'HHP', 'VHST', 'Hong Kong Shun Tak Sheung Wan Heliport', NULL, 'HK', 'Hong Kong', 22.2888000, 114.1524000, 'active', '2026-01-31 19:23:51', '2026-01-31 19:23:51'),
(3487, 'HKG', 'VHHH', 'Hong Kong International Airport (Chek Lap Kok Airport)', NULL, 'HK', 'Hong Kong', 22.3089000, 113.9150000, 'active', '2026-01-31 19:23:51', '2026-01-31 19:23:51'),
(3488, 'LCE', 'MHLC', 'Goloson International Airport', NULL, 'HN', 'Atlantida', 15.7425000, -86.8530000, 'active', '2026-01-31 19:23:52', '2026-01-31 19:23:52'),
(3489, 'TEA', 'MHTE', 'Tela Airport', NULL, 'HN', 'Atlantida', 15.7759000, -87.4758000, 'active', '2026-01-31 19:23:52', '2026-01-31 19:23:52'),
(3490, 'IRN', 'MHIR', 'Iriona Airport', NULL, 'HN', 'Colon', 15.9392000, -85.1372000, 'active', '2026-01-31 19:23:52', '2026-01-31 19:23:52'),
(3491, 'LMH', NULL, 'Limon Airport', NULL, 'HN', 'Colon', 14.3819000, -87.6211000, 'active', '2026-01-31 19:23:53', '2026-01-31 19:23:53'),
(3492, 'TCF', NULL, 'Tocoa Airport', NULL, 'HN', 'Colon', 15.6500000, -85.9830000, 'active', '2026-01-31 19:23:53', '2026-01-31 19:23:53'),
(3493, 'TJI', 'MHTJ', 'Trujillo Airport (Capiro Airport)', NULL, 'HN', 'Colon', 15.9268000, -85.9382000, 'active', '2026-01-31 19:23:53', '2026-01-31 19:23:53'),
(3494, 'XPL', 'MHSC', 'Soto Cano Air Base', NULL, 'HN', 'Comayagua', 14.3824000, -87.6212000, 'active', '2026-01-31 19:23:54', '2026-01-31 19:23:54'),
(3495, 'RUY', 'MHRU', 'Copan Ruinas Airport', NULL, 'HN', 'Copan', 14.9149000, -89.0078000, 'active', '2026-01-31 19:23:54', '2026-01-31 19:23:54'),
(3496, 'SDH', 'MHSR', 'Santa Rosa de Copan Airport', NULL, 'HN', 'Copan', 14.7779000, -88.7750000, 'active', '2026-01-31 19:23:54', '2026-01-31 19:23:54'),
(3497, 'LLH', NULL, 'Las Limas Airport', NULL, 'HN', 'Cortes', 15.4422000, -87.8988000, 'active', '2026-01-31 19:23:55', '2026-01-31 19:23:55'),
(3498, 'SAP', 'MHLM', 'Ramon Villeda Morales International Airport', NULL, 'HN', 'Cortes', 15.4526000, -87.9236000, 'active', '2026-01-31 19:23:55', '2026-01-31 19:23:55'),
(3499, 'TGU', 'MHTG', 'Toncontin International Airport', NULL, 'HN', 'Francisco Morazan', 14.0609000, -87.2172000, 'active', '2026-01-31 19:23:55', '2026-01-31 19:23:55'),
(3500, 'AHS', 'MHAH', 'Ahuas Airport', NULL, 'HN', 'Gracias a Dios', 15.4722000, -84.3522000, 'active', '2026-01-31 19:23:56', '2026-01-31 19:23:56'),
(3501, 'BHG', NULL, 'Brus Laguna Airport', NULL, 'HN', 'Gracias a Dios', 15.7631000, -84.5436000, 'active', '2026-01-31 19:23:56', '2026-01-31 19:23:56'),
(3502, 'CDD', NULL, 'Cauquira Airport', NULL, 'HN', 'Gracias a Dios', 15.3167000, -83.5917000, 'active', '2026-01-31 19:23:56', '2026-01-31 19:23:56'),
(3503, 'PCH', 'MHPC', 'Palacios Airport', NULL, 'HN', 'Gracias a Dios', 15.9550000, -84.9414000, 'active', '2026-01-31 19:23:57', '2026-01-31 19:23:57'),
(3504, 'PEU', 'MHPL', 'Puerto Lempira Airport', NULL, 'HN', 'Gracias a Dios', 15.2622000, -83.7812000, 'active', '2026-01-31 19:23:57', '2026-01-31 19:23:57'),
(3505, 'LEZ', 'MHLE', 'La Esperanza Airport', NULL, 'HN', 'Intibuca', 14.2911000, -88.1750000, 'active', '2026-01-31 19:23:57', '2026-01-31 19:23:57'),
(3506, 'GJA', 'MHNJ', 'Guanaja Airport', NULL, 'HN', 'Islas de la Bahia', 16.4454000, -85.9066000, 'active', '2026-01-31 19:23:58', '2026-01-31 19:23:58'),
(3507, 'RTB', 'MHRO', 'Juan Manuel Galvez International Airport', NULL, 'HN', 'Islas de la Bahia', 16.3168000, -86.5230000, 'active', '2026-01-31 19:23:58', '2026-01-31 19:23:58'),
(3508, 'UII', 'MHUT', 'Utila Airport', NULL, 'HN', 'Islas de la Bahia', 16.1131000, -86.8803000, 'active', '2026-01-31 19:23:58', '2026-01-31 19:23:58'),
(3509, 'MRJ', 'MHMA', 'Marcala Airport', NULL, 'HN', 'La Paz', 14.1619000, -88.0344000, 'active', '2026-01-31 19:23:59', '2026-01-31 19:23:59'),
(3510, 'EDQ', NULL, 'Erandique Airport', NULL, 'HN', 'Lempira', 14.2358000, -88.4372000, 'active', '2026-01-31 19:23:59', '2026-01-31 19:23:59'),
(3511, 'GAC', 'MHGS', 'Gracias Airport', NULL, 'HN', 'Lempira', 14.5735000, -88.5958000, 'active', '2026-01-31 19:23:59', '2026-01-31 19:23:59'),
(3512, 'CAA', 'MHGE', 'El Aguacate Airport', NULL, 'HN', 'Olancho', 14.9170000, -85.9000000, 'active', '2026-01-31 19:24:00', '2026-01-31 19:24:00'),
(3513, 'JUT', 'MHJU', 'Juticalpa Airport', NULL, 'HN', 'Olancho', 14.6526000, -86.2203000, 'active', '2026-01-31 19:24:00', '2026-01-31 19:24:00'),
(3514, 'LUI', NULL, 'La Union Airport', NULL, 'HN', 'Olancho', 15.0332000, -86.6923000, 'active', '2026-01-31 19:24:00', '2026-01-31 19:24:00'),
(3515, 'CYL', 'MHCS', 'Coyoles Airport', NULL, 'HN', 'Yoro', 15.4456000, -86.6753000, 'active', '2026-01-31 19:24:01', '2026-01-31 19:24:01'),
(3516, 'OAN', 'MHEA', 'El Arrayan Airport', NULL, 'HN', 'Yoro', 15.5056000, -86.5747000, 'active', '2026-01-31 19:24:01', '2026-01-31 19:24:01'),
(3517, 'ORO', 'MHYR', 'Yoro Airport', NULL, 'HN', 'Yoro', 15.1275000, -87.1350000, 'active', '2026-01-31 19:24:01', '2026-01-31 19:24:01'),
(3518, 'SCD', 'MHUL', 'Sulaco Airport', NULL, 'HN', 'Yoro', 14.9072000, -87.2634000, 'active', '2026-01-31 19:24:02', '2026-01-31 19:24:02'),
(3519, 'DBV', 'LDDU', 'Dubrovnik Airport', NULL, 'HR', 'Dubrovacko-neretvanska zupanija', 42.5614000, 18.2682000, 'active', '2026-01-31 19:24:02', '2026-01-31 19:24:02'),
(3520, 'ZAG', 'LDZA', 'Zagreb Airport', NULL, 'HR', 'Grad Zagreb', 45.7429000, 16.0688000, 'active', '2026-01-31 19:24:02', '2026-01-31 19:24:02'),
(3521, 'PUY', 'LDPL', 'Pula Airport', NULL, 'HR', 'Istarska zupanija', 44.8935000, 13.9222000, 'active', '2026-01-31 19:24:03', '2026-01-31 19:24:03'),
(3522, 'OSI', 'LDOS', 'Osijek Airport', NULL, 'HR', 'Osjecko-baranjska zupanija', 45.4627000, 18.8102000, 'active', '2026-01-31 19:24:03', '2026-01-31 19:24:03'),
(3523, 'LSZ', 'LDLO', 'Losinj Airport', NULL, 'HR', 'Primorsko-goranska zupanija', 44.5658000, 14.3931000, 'active', '2026-01-31 19:24:03', '2026-01-31 19:24:03'),
(3524, 'RJK', 'LDRI', 'Rijeka Airport', NULL, 'HR', 'Primorsko-goranska zupanija', 45.2169000, 14.5703000, 'active', '2026-01-31 19:24:04', '2026-01-31 19:24:04'),
(3525, 'BWK', 'LDSB', 'Bol Airport (Brac Airport)', NULL, 'HR', 'Splitsko-dalmatinska zupanija', 43.2857000, 16.6797000, 'active', '2026-01-31 19:24:04', '2026-01-31 19:24:04'),
(3526, 'SPU', 'LDSP', 'Split Airport', NULL, 'HR', 'Splitsko-dalmatinska zupanija', 43.5389000, 16.2980000, 'active', '2026-01-31 19:24:05', '2026-01-31 19:24:05'),
(3527, 'ZAD', 'LDZD', 'Zadar Airport', NULL, 'HR', 'Zadarska zupanija', 44.1083000, 15.3467000, 'active', '2026-01-31 19:24:05', '2026-01-31 19:24:05'),
(3528, 'JEE', 'MTJE', 'Jeremie Airport', NULL, 'HT', 'Grande\'Anse', 18.6631000, -74.1703000, 'active', '2026-01-31 19:24:05', '2026-01-31 19:24:05'),
(3529, 'CAP', 'MTCH', 'Hugo Chavez International Airport', NULL, 'HT', 'Nord', 19.7330000, -72.1947000, 'active', '2026-01-31 19:24:06', '2026-01-31 19:24:06'),
(3530, 'PAX', 'MTPX', 'Port-de-Paix Airport', NULL, 'HT', 'Nord-Ouest', 19.9336000, -72.8486000, 'active', '2026-01-31 19:24:06', '2026-01-31 19:24:06'),
(3531, 'PAP', 'MTPP', 'Toussaint Louverture International Airport', NULL, 'HT', 'Ouest', 18.5800000, -72.2925000, 'active', '2026-01-31 19:24:06', '2026-01-31 19:24:06'),
(3532, 'CYA', 'MTCA', 'Antoine-Simon Airport', NULL, 'HT', 'Sud', 18.2711000, -73.7883000, 'active', '2026-01-31 19:24:07', '2026-01-31 19:24:07'),
(3533, 'JAK', 'MTJA', 'Jacmel Airport', NULL, 'HT', 'Sud-Est', 18.2411000, -72.5185000, 'active', '2026-01-31 19:24:07', '2026-01-31 19:24:07'),
(3534, 'PEV', 'LHPP', 'Pecs-Pogany International Airport', NULL, 'HU', 'Baranya', 45.9909000, 18.2410000, 'active', '2026-01-31 19:24:07', '2026-01-31 19:24:07'),
(3535, 'BUD', 'LHBP', 'Budapest Ferenc Liszt International Airport', NULL, 'HU', 'Budapest', 47.4298000, 19.2611000, 'active', '2026-01-31 19:24:08', '2026-01-31 19:24:08'),
(3536, 'MCQ', 'LHMC', 'Miskolc Airport', NULL, 'HU', 'Gyor-Moson-Sopron', 48.1369000, 20.7914000, 'active', '2026-01-31 19:24:08', '2026-01-31 19:24:08'),
(3537, 'DEB', 'LHDC', 'Debrecen International Airport', NULL, 'HU', 'Hajdu-Bihar', 47.4889000, 21.6153000, 'active', '2026-01-31 19:24:08', '2026-01-31 19:24:08'),
(3538, 'SOB', 'LHSM', 'Heviz-Balaton Airport', NULL, 'HU', 'Zala', 46.6864000, 17.1591000, 'active', '2026-01-31 19:24:09', '2026-01-31 19:24:09'),
(3539, 'BTJ', 'WITT', 'Sultan Iskandar Muda International Airport', NULL, 'ID', 'Aceh', 5.5228700, 95.4206000, 'active', '2026-01-31 19:24:09', '2026-01-31 19:24:09'),
(3540, 'KJX', NULL, 'Blangpidie Airport', NULL, 'ID', 'Aceh', 3.7344400, 96.7911000, 'active', '2026-01-31 19:24:09', '2026-01-31 19:24:09'),
(3541, 'LSW', 'WITM', 'Malikus Saleh Airport', NULL, 'ID', 'Aceh', 5.2266800, 96.9503000, 'active', '2026-01-31 19:24:10', '2026-01-31 19:24:10'),
(3542, 'LSX', 'WITL', 'Lhok Sukon Airport', NULL, 'ID', 'Aceh', 5.0695100, 97.2592000, 'active', '2026-01-31 19:24:10', '2026-01-31 19:24:10'),
(3543, 'MEQ', 'WITC', 'Cut Nyak Dhien Airport', NULL, 'ID', 'Aceh', 4.2500000, 96.2170000, 'active', '2026-01-31 19:24:10', '2026-01-31 19:24:10'),
(3544, 'SBG', 'WITN', 'Maimun Saleh Airport', NULL, 'ID', 'Aceh', 5.8741300, 95.3397000, 'active', '2026-01-31 19:24:11', '2026-01-31 19:24:11'),
(3545, 'DPS', 'WADD', 'Ngurah Rai International Airport', NULL, 'ID', 'Bali', -8.7481700, 115.1670000, 'active', '2026-01-31 19:24:11', '2026-01-31 19:24:11'),
(3546, 'CGK', 'WIII', 'Soekarno–Hatta International Airport', NULL, 'ID', 'Banten', -6.1255600, 106.6560000, 'active', '2026-01-31 19:24:11', '2026-01-31 19:24:11'),
(3547, 'PCB', 'WIHP', 'Pondok Cabe Airport', NULL, 'ID', 'Banten', -6.3369600, 106.7650000, 'active', '2026-01-31 19:24:12', '2026-01-31 19:24:12'),
(3548, 'PPJ', 'WIIG', 'Panjang Island Airport', NULL, 'ID', 'Banten', -5.6444400, 106.5620000, 'active', '2026-01-31 19:24:12', '2026-01-31 19:24:12'),
(3549, 'BKS', 'WIPL', 'Fatmawati Soekarno Airport', NULL, 'ID', 'Bengkulu', -3.8637000, 102.3390000, 'active', '2026-01-31 19:24:12', '2026-01-31 19:24:12'),
(3550, 'BUU', 'WIPI', 'Muara Bungo Airport', NULL, 'ID', 'Bengkulu', -1.1278000, 102.1350000, 'active', '2026-01-31 19:24:13', '2026-01-31 19:24:13'),
(3551, 'RGT', 'WIBJ', 'Japura Airport', NULL, 'ID', 'Bengkulu', -0.3528080, 102.3350000, 'active', '2026-01-31 19:24:13', '2026-01-31 19:24:13');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(3552, 'BXW', 'WARW', 'Bawean Airport', NULL, 'ID', 'East Java', -5.7236100, 112.6790000, 'active', '2026-01-31 19:24:13', '2026-01-31 19:24:13'),
(3553, 'GTO', 'WAMG', 'Jalaluddin Airport', NULL, 'ID', 'Gorontalo', 0.6371190, 122.8500000, 'active', '2026-01-31 19:24:14', '2026-01-31 19:24:14'),
(3554, 'OJU', NULL, 'Tanjung Api Airport', NULL, 'ID', 'Gorontalo', -0.8644170, 121.6230000, 'active', '2026-01-31 19:24:14', '2026-01-31 19:24:14'),
(3555, 'UOL', 'WAMY', 'Pogogul Airport', NULL, 'ID', 'Gorontalo', 1.1027000, 121.4140000, 'active', '2026-01-31 19:24:14', '2026-01-31 19:24:14'),
(3556, 'HLP', 'WIHH', 'Halim Perdanakusuma International Airport', NULL, 'ID', 'Jakarta', -6.2655000, 106.8856000, 'active', '2026-01-31 19:24:15', '2026-01-31 19:24:15'),
(3557, 'DJB', 'WIPA', 'Sultan Thaha Airport', NULL, 'ID', 'Jambi', -1.6380200, 103.6440000, 'active', '2026-01-31 19:24:15', '2026-01-31 19:24:15'),
(3558, 'KRC', 'WIPH', 'Depati Parbo Airport', NULL, 'ID', 'Jambi', -2.0930000, 101.4680000, 'active', '2026-01-31 19:24:15', '2026-01-31 19:24:15'),
(3559, 'MPC', 'WIPU', 'Muko-Muko Airport', NULL, 'ID', 'Jambi', -2.5418600, 101.0880000, 'active', '2026-01-31 19:24:16', '2026-01-31 19:24:16'),
(3560, 'TJB', 'WIBT', 'Sei Bati Airport', NULL, 'ID', 'Jambi', 1.0527000, 103.3930000, 'active', '2026-01-31 19:24:16', '2026-01-31 19:24:16'),
(3561, 'BDO', 'WICC', 'Husein Sastranegara International Airport', NULL, 'ID', 'Jawa Barat', -6.9006300, 107.5760000, 'active', '2026-01-31 19:24:17', '2026-01-31 19:24:17'),
(3562, 'CBN', 'WICD', 'Penggung Airport (Cakrabuwana Airport)', NULL, 'ID', 'Jawa Barat', -6.7561400, 108.5400000, 'active', '2026-01-31 19:24:17', '2026-01-31 19:24:17'),
(3563, 'CJN', 'WICN', 'Cijulang Nusawiru Airport', NULL, 'ID', 'Jawa Barat', -7.7198900, 108.4890000, 'active', '2026-01-31 19:24:17', '2026-01-31 19:24:17'),
(3564, 'KJT', 'WICA', 'Kertajati International Airport', NULL, 'ID', 'Jawa Barat', -6.6489200, 108.1670000, 'active', '2026-01-31 19:24:18', '2026-01-31 19:24:18'),
(3565, 'TSY', 'WICM', 'Tasikmalaya Airport', NULL, 'ID', 'Jawa Barat', -7.3466000, 108.2460000, 'active', '2026-01-31 19:24:18', '2026-01-31 19:24:18'),
(3566, 'CPF', 'WARC', 'Ngloram Airport', NULL, 'ID', 'Jawa Tengah', -7.1948400, 111.5480000, 'active', '2026-01-31 19:24:18', '2026-01-31 19:24:18'),
(3567, 'CXP', 'WAHL', 'Tunggul Wulung Airport', NULL, 'ID', 'Jawa Tengah', -7.6450600, 109.0340000, 'active', '2026-01-31 19:24:19', '2026-01-31 19:24:19'),
(3568, 'KWB', NULL, 'Dewadaru Airport', NULL, 'ID', 'Jawa Tengah', -5.8009100, 110.4780000, 'active', '2026-01-31 19:24:19', '2026-01-31 19:24:19'),
(3569, 'PWL', 'WAHP', 'Wirasaba Airport', NULL, 'ID', 'Jawa Tengah', -7.4616700, 109.4170000, 'active', '2026-01-31 19:24:20', '2026-01-31 19:24:20'),
(3570, 'SOC', 'WARQ', 'Adisumarmo International Airport', NULL, 'ID', 'Jawa Tengah', -7.5160900, 110.7570000, 'active', '2026-01-31 19:24:21', '2026-01-31 19:24:21'),
(3571, 'SRG', 'WARS', 'Achmad Yani International Airport', NULL, 'ID', 'Jawa Tengah', -6.9727300, 110.3750000, 'active', '2026-01-31 19:24:21', '2026-01-31 19:24:21'),
(3572, 'YIA', 'WAHI', 'Yogyakarta International Airport', NULL, 'ID', 'Jawa Tengah', -7.9053400, 110.0570000, 'active', '2026-01-31 19:24:22', '2026-01-31 19:24:22'),
(3573, 'BWX', 'WADY', 'Blimbingsari Airport', NULL, 'ID', 'Jawa Timur', -8.3101500, 114.3400000, 'active', '2026-01-31 19:24:22', '2026-01-31 19:24:22'),
(3574, 'DHX', NULL, 'Dhoho International Airport', NULL, 'ID', 'Jawa Timur', -7.7613200, 111.9504000, 'active', '2026-01-31 19:24:22', '2026-01-31 19:24:22'),
(3575, 'JBB', 'WARE', 'Notohadinegoro Airport', NULL, 'ID', 'Jawa Timur', -8.2380600, 113.6940000, 'active', '2026-01-31 19:24:23', '2026-01-31 19:24:23'),
(3576, 'MLG', 'WARA', 'Abdul Rachman Saleh Airport', NULL, 'ID', 'Jawa Timur', -7.9265600, 112.7150000, 'active', '2026-01-31 19:24:23', '2026-01-31 19:24:23'),
(3577, 'MSI', NULL, 'Masalembo Airport', NULL, 'ID', 'Jawa Timur', -5.5833300, 114.4330000, 'active', '2026-01-31 19:24:23', '2026-01-31 19:24:23'),
(3578, 'SUB', 'WARR', 'Juanda International Airport', NULL, 'ID', 'Jawa Timur', -7.3798300, 112.7870000, 'active', '2026-01-31 19:24:24', '2026-01-31 19:24:24'),
(3579, 'SUP', 'WART', 'Trunojoyo Airport', NULL, 'ID', 'Jawa Timur', -7.0242000, 113.8900000, 'active', '2026-01-31 19:24:24', '2026-01-31 19:24:24'),
(3580, 'KTG', 'WIOK', 'Rahadi Osman Airport (Ketapang Airport)', NULL, 'ID', 'Kalimantan Barat', -1.8166400, 109.9630000, 'active', '2026-01-31 19:24:24', '2026-01-31 19:24:24'),
(3581, 'PNK', 'WIOO', 'Supadio Airport', NULL, 'ID', 'Kalimantan Barat', -0.1507110, 109.4040000, 'active', '2026-01-31 19:24:25', '2026-01-31 19:24:25'),
(3582, 'PSU', 'WIOP', 'Pangsuma Airport', NULL, 'ID', 'Kalimantan Barat', 0.8355780, 112.9370000, 'active', '2026-01-31 19:24:25', '2026-01-31 19:24:25'),
(3583, 'SQG', 'WIOS', 'Sintang Airport (Susilo Airport)', NULL, 'ID', 'Kalimantan Barat', 0.0636190, 111.4730000, 'active', '2026-01-31 19:24:26', '2026-01-31 19:24:26'),
(3584, 'BDJ', 'WAOO', 'Syamsudin Noor Airport', NULL, 'ID', 'Kalimantan Selatan', -3.4423600, 114.7630000, 'active', '2026-01-31 19:24:26', '2026-01-31 19:24:26'),
(3585, 'BTW', 'WAOC', 'Batu Licin Airport', NULL, 'ID', 'Kalimantan Selatan', -3.4124100, 115.9950000, 'active', '2026-01-31 19:24:26', '2026-01-31 19:24:26'),
(3586, 'KBU', 'WRBK', 'Gusti Syamsir Alam Airport (Stagen Airport)', NULL, 'ID', 'Kalimantan Selatan', -3.2947200, 116.1650000, 'active', '2026-01-31 19:24:27', '2026-01-31 19:24:27'),
(3587, 'TJG', 'WAON', 'Warukin Airport', NULL, 'ID', 'Kalimantan Selatan', -2.2165600, 115.4360000, 'active', '2026-01-31 19:24:27', '2026-01-31 19:24:27'),
(3588, 'HMS', NULL, 'Bandar Udara Haji Muhammad Sidik Muara Teweh Airport', NULL, 'ID', 'Kalimantan Tengah', -1.0221000, 114.9276000, 'active', '2026-01-31 19:24:27', '2026-01-31 19:24:27'),
(3589, 'NPO', 'WIOG', 'Nanga Pinoh Airport', NULL, 'ID', 'Kalimantan Tengah', -0.3488690, 111.7480000, 'active', '2026-01-31 19:24:28', '2026-01-31 19:24:28'),
(3590, 'PKN', 'WAOI', 'Iskandar Airport', NULL, 'ID', 'Kalimantan Tengah', -2.7052000, 111.6730000, 'active', '2026-01-31 19:24:28', '2026-01-31 19:24:28'),
(3591, 'PKY', 'WAGG', 'Tjilik Riwut Airport', NULL, 'ID', 'Kalimantan Tengah', -2.2251300, 113.9430000, 'active', '2026-01-31 19:24:28', '2026-01-31 19:24:28'),
(3592, 'SMQ', 'WAOS', 'H. Asan Airport', NULL, 'ID', 'Kalimantan Tengah', -2.4991900, 112.9750000, 'active', '2026-01-31 19:24:29', '2026-01-31 19:24:29'),
(3593, 'TBM', 'WAOW', 'Tumbang Samba Airport', NULL, 'ID', 'Kalimantan Tengah', -1.4694000, 113.0830000, 'active', '2026-01-31 19:24:29', '2026-01-31 19:24:29'),
(3594, 'AAP', 'WALS', 'APT Pranoto International Airport', NULL, 'ID', 'Kalimantan Timur', -0.3744480, 117.2490000, 'active', '2026-01-31 19:24:29', '2026-01-31 19:24:29'),
(3595, 'BEJ', 'WALK', 'Kalimarau Airport', NULL, 'ID', 'Kalimantan Timur', 2.1555000, 117.4320000, 'active', '2026-01-31 19:24:30', '2026-01-31 19:24:30'),
(3596, 'BPN', 'WALL', 'Sultan Aji Muhammad Sulaiman Airport', NULL, 'ID', 'Kalimantan Timur', -1.2682700, 116.8940000, 'active', '2026-01-31 19:24:30', '2026-01-31 19:24:30'),
(3597, 'BXT', 'WRLC', 'PT Badak Bontang Airport', NULL, 'ID', 'Kalimantan Timur', 0.1196910, 117.4750000, 'active', '2026-01-31 19:24:30', '2026-01-31 19:24:30'),
(3598, 'DTD', 'WALJ', 'Datadawai Airport', NULL, 'ID', 'Kalimantan Timur', 0.8106000, 114.5310000, 'active', '2026-01-31 19:24:31', '2026-01-31 19:24:31'),
(3599, 'GHS', 'WALE', 'West Kutai Airport', NULL, 'ID', 'Kalimantan Timur', -0.2064000, 115.7604500, 'active', '2026-01-31 19:24:31', '2026-01-31 19:24:31'),
(3600, 'KOD', NULL, 'Kotabangun Airport', NULL, 'ID', 'Kalimantan Timur', -0.2666700, 116.5830000, 'active', '2026-01-31 19:24:32', '2026-01-31 19:24:32'),
(3601, 'SGQ', 'WRLA', 'Sangkimah Airport', NULL, 'ID', 'Kalimantan Timur', 0.3847000, 117.5430000, 'active', '2026-01-31 19:24:32', '2026-01-31 19:24:32'),
(3602, 'TNB', 'WRLH', 'Tanah Grogot Airport', NULL, 'ID', 'Kalimantan Timur', -1.9101300, 116.2020000, 'active', '2026-01-31 19:24:32', '2026-01-31 19:24:32'),
(3603, 'TSX', 'WALT', 'Tanjung Santan Airport', NULL, 'ID', 'Kalimantan Timur', -0.0929730, 117.4530000, 'active', '2026-01-31 19:24:33', '2026-01-31 19:24:33'),
(3604, 'BYQ', 'WALV', 'Bunyu Airport', NULL, 'ID', 'Kalimantan Utara', 3.4557200, 117.8670000, 'active', '2026-01-31 19:24:33', '2026-01-31 19:24:33'),
(3605, 'LBW', 'WRLB', 'Juvai Semaring Airport (Long Bawan Airport)', NULL, 'ID', 'Kalimantan Utara', 3.9028000, 115.6920000, 'active', '2026-01-31 19:24:33', '2026-01-31 19:24:33'),
(3606, 'LNU', 'WALM', 'Malinau Robbert Atty Bessing Airport', NULL, 'ID', 'Kalimantan Utara', 3.5764000, 116.6182000, 'active', '2026-01-31 19:24:34', '2026-01-31 19:24:34'),
(3607, 'LPU', 'WRLP', 'Long Apung Airport', NULL, 'ID', 'Kalimantan Utara', 1.7044900, 114.9700000, 'active', '2026-01-31 19:24:34', '2026-01-31 19:24:34'),
(3608, 'NAF', NULL, 'Banaina Airport', NULL, 'ID', 'Kalimantan Utara', 2.7230500, 117.1260000, 'active', '2026-01-31 19:24:34', '2026-01-31 19:24:34'),
(3609, 'NNX', 'WRLF', 'Nunukan Airport', NULL, 'ID', 'Kalimantan Utara', 4.1333300, 117.6670000, 'active', '2026-01-31 19:24:35', '2026-01-31 19:24:35'),
(3610, 'TJS', 'WAGD', 'Tanjung Harapan Airport', NULL, 'ID', 'Kalimantan Utara', 2.8358300, 117.3740000, 'active', '2026-01-31 19:24:35', '2026-01-31 19:24:35'),
(3611, 'TPK', 'WITA', 'Teuku Cut Ali Airport', NULL, 'ID', 'Kalimantan Utara', 3.1707000, 97.2869000, 'active', '2026-01-31 19:24:35', '2026-01-31 19:24:35'),
(3612, 'TRK', 'WALR', 'Juwata International Airport', NULL, 'ID', 'Kalimantan Utara', 3.3266700, 117.5690000, 'active', '2026-01-31 19:24:36', '2026-01-31 19:24:36'),
(3613, 'MWK', 'WIOM', 'Matak Airport (Tarempa Airport)', NULL, 'ID', 'Kepulauan Bangka Belitung', 3.3481200, 106.2580000, 'active', '2026-01-31 19:24:36', '2026-01-31 19:24:36'),
(3614, 'PGK', 'WIPK', 'Depati Amir Airport', NULL, 'ID', 'Kepulauan Bangka Belitung', -2.1622000, 106.1390000, 'active', '2026-01-31 19:24:36', '2026-01-31 19:24:36'),
(3615, 'TJQ', 'WIKD', 'H.A.S. Hanandjoeddin Airport (Buluh Tumbang Airport)', NULL, 'ID', 'Kepulauan Bangka Belitung', -2.7457200, 107.7550000, 'active', '2026-01-31 19:24:37', '2026-01-31 19:24:37'),
(3616, 'BTH', 'WIDD', 'Hang Nadim Airport', NULL, 'ID', 'Kepulauan Riau', 1.1210300, 104.1190000, 'active', '2026-01-31 19:24:37', '2026-01-31 19:24:37'),
(3617, 'LMU', 'WIDL', 'Letung Anambas Jemaja Island Airport', NULL, 'ID', 'Kepulauan Riau', 2.9621000, 105.7551000, 'active', '2026-01-31 19:24:37', '2026-01-31 19:24:37'),
(3618, 'NTX', 'WION', 'Ranai Airport', NULL, 'ID', 'Kepulauan Riau', 3.9087100, 108.3880000, 'active', '2026-01-31 19:24:38', '2026-01-31 19:24:38'),
(3619, 'TNJ', 'WIDN', 'Raja Haji Fisabilillah Airport', NULL, 'ID', 'Kepulauan Riau', 0.9226830, 104.5320000, 'active', '2026-01-31 19:24:38', '2026-01-31 19:24:38'),
(3620, 'AKQ', 'WIAG', 'Gunung Batin Airport', NULL, 'ID', 'Lampung', -4.6111400, 105.2320000, 'active', '2026-01-31 19:24:38', '2026-01-31 19:24:38'),
(3621, 'TKG', 'WILL', 'Radin Inten II Airport', NULL, 'ID', 'Lampung', -5.2405600, 105.1760000, 'active', '2026-01-31 19:24:39', '2026-01-31 19:24:39'),
(3622, 'GLX', 'WAMA', 'Gamarmalamo Airport', NULL, 'ID', 'Maluku Utara', 1.8383300, 127.7860000, 'active', '2026-01-31 19:24:39', '2026-01-31 19:24:39'),
(3623, 'LAH', 'WAPH', 'Oesman Sadik Airport', NULL, 'ID', 'Maluku Utara', -0.6352590, 127.5020000, 'active', '2026-01-31 19:24:39', '2026-01-31 19:24:39'),
(3624, 'MAL', 'WAPE', 'Mangole Airport', NULL, 'ID', 'Maluku Utara', -1.8757900, 125.8300000, 'active', '2026-01-31 19:24:40', '2026-01-31 19:24:40'),
(3625, 'OTI', 'WAMR', 'Pitu Airport', NULL, 'ID', 'Maluku Utara', 2.0459900, 128.3250000, 'active', '2026-01-31 19:24:40', '2026-01-31 19:24:40'),
(3626, 'SQN', 'WAPN', 'Sanana Airport', NULL, 'ID', 'Maluku Utara', -2.0805100, 125.9670000, 'active', '2026-01-31 19:24:40', '2026-01-31 19:24:40'),
(3627, 'TAX', 'WAPT', 'Taliabu Airport', NULL, 'ID', 'Maluku Utara', -1.6426300, 124.5590000, 'active', '2026-01-31 19:24:41', '2026-01-31 19:24:41'),
(3628, 'TTE', 'WAEE', 'Sultan Babullah Airport', NULL, 'ID', 'Maluku Utara', 0.8314140, 127.3810000, 'active', '2026-01-31 19:24:41', '2026-01-31 19:24:41'),
(3629, 'AHI', 'WAPA', 'Amahai Airport', NULL, 'ID', 'Maluku', -3.3480000, 128.9260000, 'active', '2026-01-31 19:24:41', '2026-01-31 19:24:41'),
(3630, 'AMQ', 'WAPP', 'Pattimura Airport', NULL, 'ID', 'Maluku', -3.7102600, 128.0890000, 'active', '2026-01-31 19:24:42', '2026-01-31 19:24:42'),
(3631, 'BJK', 'WAPK', 'Benjina Airport (Nangasuri Airport)', NULL, 'ID', 'Maluku', -6.0662000, 134.2740000, 'active', '2026-01-31 19:24:42', '2026-01-31 19:24:42'),
(3632, 'DOB', 'WAPD', 'Dobo Airport', NULL, 'ID', 'Maluku', -5.7722200, 134.2120000, 'active', '2026-01-31 19:24:42', '2026-01-31 19:24:42'),
(3633, 'GEB', 'WAMJ', 'Gebe Airport', NULL, 'ID', 'Maluku', -0.0788890, 129.4580000, 'active', '2026-01-31 19:24:43', '2026-01-31 19:24:43'),
(3634, 'JIO', NULL, 'Jos Orno Imsula Airport', NULL, 'ID', 'Maluku', -8.1419000, 127.9098300, 'active', '2026-01-31 19:24:43', '2026-01-31 19:24:43'),
(3635, 'KAZ', 'WAMK', 'Kao Airport', NULL, 'ID', 'Maluku', 1.1852800, 127.8960000, 'active', '2026-01-31 19:24:43', '2026-01-31 19:24:43'),
(3636, 'LUV', 'WAPF', 'Karel Sadsuitubun Airport', NULL, 'ID', 'Maluku', -5.7602800, 132.7590000, 'active', '2026-01-31 19:24:44', '2026-01-31 19:24:44'),
(3637, 'NAM', 'WAPR', 'Namlea Airport', NULL, 'ID', 'Maluku', -3.2355700, 127.1000000, 'active', '2026-01-31 19:24:44', '2026-01-31 19:24:44'),
(3638, 'NDA', 'WAPC', 'Bandanaira Airport', NULL, 'ID', 'Maluku', -4.5214000, 129.9050000, 'active', '2026-01-31 19:24:44', '2026-01-31 19:24:44'),
(3639, 'NRE', 'WAPG', 'Namrole Airport', NULL, 'ID', 'Maluku', -3.8548000, 126.7010000, 'active', '2026-01-31 19:24:45', '2026-01-31 19:24:45'),
(3640, 'SXK', 'WAPI', 'Saumlaki Airport (Olilit Airport)', NULL, 'ID', 'Maluku', -7.9886100, 131.3060000, 'active', '2026-01-31 19:24:45', '2026-01-31 19:24:45'),
(3641, 'WBA', 'WAPV', 'Wahai Airport', NULL, 'ID', 'Maluku', -2.8114000, 129.4840000, 'active', '2026-01-31 19:24:45', '2026-01-31 19:24:45'),
(3642, 'BMU', 'WADB', 'Sultan Muhammad Salahudin Airport (Bima Airport)', NULL, 'ID', 'Nusa Tenggara Barat', -8.5396500, 118.6870000, 'active', '2026-01-31 19:24:46', '2026-01-31 19:24:46'),
(3643, 'LOP', 'WADL', 'Lombok International Airport', NULL, 'ID', 'Nusa Tenggara Barat', -8.7573200, 116.2770000, 'active', '2026-01-31 19:24:46', '2026-01-31 19:24:46'),
(3644, 'LYK', 'WADU', 'Lunyuk Airport', NULL, 'ID', 'Nusa Tenggara Barat', -8.9889000, 117.2160000, 'active', '2026-01-31 19:24:47', '2026-01-31 19:24:47'),
(3645, 'SWQ', 'WADS', 'Sultan Muhammad Kaharuddin III Airport (Brangbiji Airport)', NULL, 'ID', 'Nusa Tenggara Barat', -8.4890400, 117.4120000, 'active', '2026-01-31 19:24:47', '2026-01-31 19:24:47'),
(3646, 'ABU', 'WATA', 'A.A. Bere Tallo Airport', NULL, 'ID', 'Nusa Tenggara Timur', -9.0730500, 124.9050000, 'active', '2026-01-31 19:24:47', '2026-01-31 19:24:47'),
(3647, 'ARD', 'WATM', 'Alor Island Airport', NULL, 'ID', 'Nusa Tenggara Timur', -8.1323400, 124.5970000, 'active', '2026-01-31 19:24:48', '2026-01-31 19:24:48'),
(3648, 'BJW', 'WRKB', 'Bajawa Soa Airport', NULL, 'ID', 'Nusa Tenggara Timur', -8.7074300, 121.0570000, 'active', '2026-01-31 19:24:48', '2026-01-31 19:24:48'),
(3649, 'ENE', 'WATE', 'H. Hasan Aroeboesman Airport', NULL, 'ID', 'Nusa Tenggara Timur', -8.8492900, 121.6610000, 'active', '2026-01-31 19:24:48', '2026-01-31 19:24:48'),
(3650, 'KOE', 'WATT', 'El Tari Airport', NULL, 'ID', 'Nusa Tenggara Timur', -10.1716000, 123.6710000, 'active', '2026-01-31 19:24:49', '2026-01-31 19:24:49'),
(3651, 'LBJ', 'WATO', 'Komodo Airport', NULL, 'ID', 'Nusa Tenggara Timur', -8.4866600, 119.8890000, 'active', '2026-01-31 19:24:49', '2026-01-31 19:24:49'),
(3652, 'LKA', 'WATL', 'Gewayantana Airport', NULL, 'ID', 'Nusa Tenggara Timur', -8.2744200, 123.0020000, 'active', '2026-01-31 19:24:49', '2026-01-31 19:24:49'),
(3653, 'LWE', 'WATW', 'Wonopito Airport', NULL, 'ID', 'Nusa Tenggara Timur', -8.3629000, 123.4380000, 'active', '2026-01-31 19:24:50', '2026-01-31 19:24:50'),
(3654, 'MOF', 'WATC', 'Frans Seda Airport (Wai Oti Airport)', NULL, 'ID', 'Nusa Tenggara Timur', -8.6406500, 122.2370000, 'active', '2026-01-31 19:24:50', '2026-01-31 19:24:50'),
(3655, 'RTG', 'WATG', 'Frans Sales Lega Airport', NULL, 'ID', 'Nusa Tenggara Timur', -8.5970100, 120.4770000, 'active', '2026-01-31 19:24:50', '2026-01-31 19:24:50'),
(3656, 'RTI', 'WATR', 'David Constantijn Saudale Airport', NULL, 'ID', 'Nusa Tenggara Timur', -10.7673000, 123.0750000, 'active', '2026-01-31 19:24:51', '2026-01-31 19:24:51'),
(3657, 'SAU', 'WATS', 'Tardamu Airport', NULL, 'ID', 'Nusa Tenggara Timur', -10.4924000, 121.8480000, 'active', '2026-01-31 19:24:51', '2026-01-31 19:24:51'),
(3658, 'TMC', 'WADT', 'Tambolaka Airport (Waikabubak Airport)', NULL, 'ID', 'Nusa Tenggara Timur', -9.4097200, 119.2440000, 'active', '2026-01-31 19:24:51', '2026-01-31 19:24:51'),
(3659, 'WGP', 'WADW', 'Mau Hau Airport (Umbu Mehang Kunda Airport)', NULL, 'ID', 'Nusa Tenggara Timur', -9.6692200, 120.3020000, 'active', '2026-01-31 19:24:52', '2026-01-31 19:24:52'),
(3660, 'AGD', 'WASG', 'Anggi Airport', NULL, 'ID', 'Papua Barat', -1.3858000, 133.8740000, 'active', '2026-01-31 19:24:52', '2026-01-31 19:24:52'),
(3661, 'BXB', 'WASO', 'Babo Airport', NULL, 'ID', 'Papua Barat', -2.5322400, 133.4390000, 'active', '2026-01-31 19:24:52', '2026-01-31 19:24:52'),
(3662, 'FKQ', 'WASF', 'Fakfak Torea Airport', NULL, 'ID', 'Papua Barat', -2.9201900, 132.2670000, 'active', '2026-01-31 19:24:53', '2026-01-31 19:24:53'),
(3663, 'GAV', NULL, 'Gag Island Airport', NULL, 'ID', 'Papua Barat', -0.4005560, 129.8950000, 'active', '2026-01-31 19:24:53', '2026-01-31 19:24:53'),
(3664, 'INX', 'WASI', 'Inanwatan Airport', NULL, 'ID', 'Papua Barat', -2.1281000, 132.1610000, 'active', '2026-01-31 19:24:53', '2026-01-31 19:24:53'),
(3665, 'KBX', 'WASU', 'Kambuaya Airport', NULL, 'ID', 'Papua Barat', -1.3169000, 132.2860000, 'active', '2026-01-31 19:24:54', '2026-01-31 19:24:54'),
(3666, 'KEQ', 'WASE', 'Kebar Airport', NULL, 'ID', 'Papua Barat', -0.6371010, 133.1280000, 'active', '2026-01-31 19:24:54', '2026-01-31 19:24:54'),
(3667, 'KNG', 'WASK', 'Kaimana Airport', NULL, 'ID', 'Papua Barat', -3.6445200, 133.6960000, 'active', '2026-01-31 19:24:54', '2026-01-31 19:24:54'),
(3668, 'MKW', 'WASR', 'Rendani Airport', NULL, 'ID', 'Papua Barat', -0.8918330, 134.0490000, 'active', '2026-01-31 19:24:55', '2026-01-31 19:24:55'),
(3669, 'NTI', 'WASB', 'Stenkol Airport', NULL, 'ID', 'Papua Barat', -2.1033000, 133.5160000, 'active', '2026-01-31 19:24:56', '2026-01-31 19:24:56'),
(3670, 'RDE', 'WASM', 'Merdey Airport (Jahabra Airport)', NULL, 'ID', 'Papua Barat', -1.5833300, 133.3330000, 'active', '2026-01-31 19:24:56', '2026-01-31 19:24:56'),
(3671, 'RJM', 'WASN', 'Marinda Airport', NULL, 'ID', 'Papua Barat', -0.4230560, 130.7730000, 'active', '2026-01-31 19:24:56', '2026-01-31 19:24:56'),
(3672, 'RSK', 'WASC', 'Abresso Airport', NULL, 'ID', 'Papua Barat', -1.4967700, 134.1750000, 'active', '2026-01-31 19:24:57', '2026-01-31 19:24:57'),
(3673, 'SOQ', 'WASS', 'Dominique Edward Osok Airport', NULL, 'ID', 'Papua Barat', -0.8940000, 131.2870000, 'active', '2026-01-31 19:24:57', '2026-01-31 19:24:57'),
(3674, 'TXM', 'WAST', 'Teminabuan Airport', NULL, 'ID', 'Papua Barat', -1.4447200, 132.0210000, 'active', '2026-01-31 19:24:57', '2026-01-31 19:24:57'),
(3675, 'AAS', NULL, 'Apalapsili Airport', NULL, 'ID', 'Papua', -3.8832000, 139.3110000, 'active', '2026-01-31 19:24:58', '2026-01-31 19:24:58'),
(3676, 'ARJ', 'WAJA', 'Arso Airport', NULL, 'ID', 'Papua', -2.9333300, 140.7830000, 'active', '2026-01-31 19:24:58', '2026-01-31 19:24:58'),
(3677, 'BIK', 'WABB', 'Frans Kaisiepo Airport', NULL, 'ID', 'Papua', -1.1900200, 136.1080000, 'active', '2026-01-31 19:24:58', '2026-01-31 19:24:58'),
(3678, 'BUI', 'WAJB', 'Bokondini Airport', NULL, 'ID', 'Papua', -3.6822000, 138.6760000, 'active', '2026-01-31 19:24:59', '2026-01-31 19:24:59'),
(3679, 'BXD', 'WAKE', 'Bade Airport', NULL, 'ID', 'Papua', -7.1759000, 139.5830000, 'active', '2026-01-31 19:24:59', '2026-01-31 19:24:59'),
(3680, 'BXM', 'WAJG', 'Batom Airport', NULL, 'ID', 'Papua', -4.1666700, 140.8500000, 'active', '2026-01-31 19:24:59', '2026-01-31 19:24:59'),
(3681, 'DEX', NULL, 'Nop Goliath Airport', NULL, 'ID', 'Papua', -4.8557000, 139.4820000, 'active', '2026-01-31 19:25:00', '2026-01-31 19:25:00'),
(3682, 'DJJ', 'WAJJ', 'Sentani Airport', NULL, 'ID', 'Papua', -2.5769500, 140.5160000, 'active', '2026-01-31 19:25:00', '2026-01-31 19:25:00'),
(3683, 'DRH', 'WAJC', 'Dabra Airport', NULL, 'ID', 'Papua', -3.2705000, 138.6130000, 'active', '2026-01-31 19:25:00', '2026-01-31 19:25:00'),
(3684, 'ELR', 'WAJN', 'Elelim Airport', NULL, 'ID', 'Papua', -3.7826000, 139.3860000, 'active', '2026-01-31 19:25:01', '2026-01-31 19:25:01'),
(3685, 'EWE', NULL, 'Ewer Airport', NULL, 'ID', 'Papua', -5.4940000, 138.0830000, 'active', '2026-01-31 19:25:01', '2026-01-31 19:25:01'),
(3686, 'EWI', 'WABT', 'Enarotali Airport', NULL, 'ID', 'Papua', -3.9259000, 136.3770000, 'active', '2026-01-31 19:25:01', '2026-01-31 19:25:01'),
(3687, 'FOO', NULL, 'Kornasoren Airport (Numfoor Airport)', NULL, 'ID', 'Papua', -0.9363250, 134.8720000, 'active', '2026-01-31 19:25:02', '2026-01-31 19:25:02'),
(3688, 'ILA', 'WABL', 'Illaga Airport', NULL, 'ID', 'Papua', -3.9764800, 137.6220000, 'active', '2026-01-31 19:25:02', '2026-01-31 19:25:02'),
(3689, 'IUL', 'WABE', 'Ilu Airport', NULL, 'ID', 'Papua', -3.7051000, 138.2000000, 'active', '2026-01-31 19:25:03', '2026-01-31 19:25:03'),
(3690, 'KBF', 'WABK', 'Karubaga Airport', NULL, 'ID', 'Papua', -3.6840000, 138.4790000, 'active', '2026-01-31 19:25:03', '2026-01-31 19:25:03'),
(3691, 'KCD', 'WAKM', 'Kamur Airport', NULL, 'ID', 'Papua', -6.1851000, 138.6370000, 'active', '2026-01-31 19:25:03', '2026-01-31 19:25:03'),
(3692, 'KEI', 'WAKP', 'Kepi Airport', NULL, 'ID', 'Papua', -6.5418000, 139.3320000, 'active', '2026-01-31 19:25:04', '2026-01-31 19:25:04'),
(3693, 'KMM', NULL, 'Kimam Airport', NULL, 'ID', 'Papua', -3.6666700, 136.1670000, 'active', '2026-01-31 19:25:04', '2026-01-31 19:25:04'),
(3694, 'KOX', 'WABN', 'Kokonao Airport', NULL, 'ID', 'Papua', -4.7107500, 136.4350000, 'active', '2026-01-31 19:25:04', '2026-01-31 19:25:04'),
(3695, 'LHI', 'WAJL', 'Lereh Airport', NULL, 'ID', 'Papua', -3.0795000, 139.9520000, 'active', '2026-01-31 19:25:05', '2026-01-31 19:25:05'),
(3696, 'LII', 'WAJM', 'Mulia Airport', NULL, 'ID', 'Papua', -3.7018000, 137.9570000, 'active', '2026-01-31 19:25:06', '2026-01-31 19:25:06'),
(3697, 'LLN', NULL, 'Kelila Airport', NULL, 'ID', 'Papua', -3.7500000, 138.6670000, 'active', '2026-01-31 19:25:06', '2026-01-31 19:25:06'),
(3698, 'MDP', 'WAKD', 'Mindiptana Airport', NULL, 'ID', 'Papua', -5.7500000, 140.3670000, 'active', '2026-01-31 19:25:06', '2026-01-31 19:25:06'),
(3699, 'MKQ', 'WAKK', 'Mopah Airport', NULL, 'ID', 'Papua', -8.5202900, 140.4180000, 'active', '2026-01-31 19:25:07', '2026-01-31 19:25:07'),
(3700, 'MUF', NULL, 'Muting Airport', NULL, 'ID', 'Papua', -7.3147000, 140.5670000, 'active', '2026-01-31 19:25:07', '2026-01-31 19:25:07'),
(3701, 'NBX', 'WABI', 'Nabire Airport', NULL, 'ID', 'Papua', -3.3681800, 135.4960000, 'active', '2026-01-31 19:25:07', '2026-01-31 19:25:07'),
(3702, 'NKD', NULL, 'Sinak Airport', NULL, 'ID', 'Papua', -3.8220000, 137.8410000, 'active', '2026-01-31 19:25:08', '2026-01-31 19:25:08'),
(3703, 'OBD', 'WABR', 'Obano Airport', NULL, 'ID', 'Papua', -3.9106000, 136.2310000, 'active', '2026-01-31 19:25:08', '2026-01-31 19:25:08'),
(3704, 'OKL', 'WAJO', 'Gunung Bintang Airport', NULL, 'ID', 'Papua', -4.9071000, 140.6280000, 'active', '2026-01-31 19:25:08', '2026-01-31 19:25:08'),
(3705, 'OKQ', 'WAKO', 'Okaba Airport', NULL, 'ID', 'Papua', -8.0946000, 139.7230000, 'active', '2026-01-31 19:25:09', '2026-01-31 19:25:09'),
(3706, 'ONI', 'WABD', 'Moanamani Airport', NULL, 'ID', 'Papua', -3.9834000, 136.0830000, 'active', '2026-01-31 19:25:09', '2026-01-31 19:25:09'),
(3707, 'RUF', 'WAJE', 'Yuruf Airport', NULL, 'ID', 'Papua', -3.6333000, 140.9580000, 'active', '2026-01-31 19:25:09', '2026-01-31 19:25:09'),
(3708, 'SEH', 'WAJS', 'Senggeh Airport', NULL, 'ID', 'Papua', -3.4500000, 140.7790000, 'active', '2026-01-31 19:25:10', '2026-01-31 19:25:10'),
(3709, 'TIM', 'WABP', 'Mozes Kilangin Airport', NULL, 'ID', 'Papua', -4.5282800, 136.8870000, 'active', '2026-01-31 19:25:10', '2026-01-31 19:25:10'),
(3710, 'TMH', 'WAKT', 'Tanah Merah Airport', NULL, 'ID', 'Papua', -6.0992200, 140.2980000, 'active', '2026-01-31 19:25:10', '2026-01-31 19:25:10'),
(3711, 'TMY', NULL, 'Tiom Airport', NULL, 'ID', 'Papua', -3.9256000, 138.4560000, 'active', '2026-01-31 19:25:11', '2026-01-31 19:25:11'),
(3712, 'UBR', 'WAJU', 'Ubrub Airport', NULL, 'ID', 'Papua', -3.6756500, 140.8840000, 'active', '2026-01-31 19:25:11', '2026-01-31 19:25:11'),
(3713, 'UGU', 'WABV', 'Bilogai Airport', NULL, 'ID', 'Papua', -3.7395600, 137.0320000, 'active', '2026-01-31 19:25:11', '2026-01-31 19:25:11'),
(3714, 'WAR', 'WAJR', 'Waris Airport', NULL, 'ID', 'Papua', -3.2350000, 140.9940000, 'active', '2026-01-31 19:25:12', '2026-01-31 19:25:12'),
(3715, 'WET', 'WABG', 'Waghete Airport', NULL, 'ID', 'Papua', -4.0442300, 136.2780000, 'active', '2026-01-31 19:25:12', '2026-01-31 19:25:12'),
(3716, 'WMX', 'WAVV', 'Wamena Airport', NULL, 'ID', 'Papua', -4.1025100, 138.9570000, 'active', '2026-01-31 19:25:12', '2026-01-31 19:25:12'),
(3717, 'WSR', 'WASW', 'Wasior Airport', NULL, 'ID', 'Papua', -2.7210000, 134.5060000, 'active', '2026-01-31 19:25:13', '2026-01-31 19:25:13'),
(3718, 'ZEG', 'WAKQ', 'Senggo Airport', NULL, 'ID', 'Papua', -5.6908000, 139.3500000, 'active', '2026-01-31 19:25:13', '2026-01-31 19:25:13'),
(3719, 'ZRI', 'WABO', 'Serui Airport', NULL, 'ID', 'Papua', -1.8755800, 136.2410000, 'active', '2026-01-31 19:25:13', '2026-01-31 19:25:13'),
(3720, 'ZRM', 'WAJI', 'Sarmi Orai Airport', NULL, 'ID', 'Papua', -1.8695500, 138.7500000, 'active', '2026-01-31 19:25:14', '2026-01-31 19:25:14'),
(3721, 'DUM', 'WIBD', 'Pinang Kampai Airport', NULL, 'ID', 'Riau', 1.6091900, 101.4340000, 'active', '2026-01-31 19:25:14', '2026-01-31 19:25:14'),
(3722, 'PKU', 'WIBB', 'Sultan Syarif Kasim II International Airport', NULL, 'ID', 'Riau', 0.4607860, 101.4450000, 'active', '2026-01-31 19:25:14', '2026-01-31 19:25:14'),
(3723, 'SEQ', 'WIBS', 'Sei Pakning Airport', NULL, 'ID', 'Riau', 1.3700000, 102.1400000, 'active', '2026-01-31 19:25:15', '2026-01-31 19:25:15'),
(3724, 'SIQ', 'WIDS', 'Dabo Singkep Airport', NULL, 'ID', 'Riau', -0.4791890, 104.5790000, 'active', '2026-01-31 19:25:15', '2026-01-31 19:25:15'),
(3725, 'LLJ', 'WIPB', 'Silampari Airport', NULL, 'ID', 'South Sumatra', -3.2800000, 102.9170000, 'active', '2026-01-31 19:25:15', '2026-01-31 19:25:15'),
(3726, 'MJU', 'WAFJ', 'Tampa Padang Airport', NULL, 'ID', 'Sulawesi Barat', -2.5833300, 119.0330000, 'active', '2026-01-31 19:25:16', '2026-01-31 19:25:16'),
(3727, 'TTR', 'WAWT', 'Pongtiku Airport', NULL, 'ID', 'Sulawesi Barat', -3.0447400, 119.8220000, 'active', '2026-01-31 19:25:16', '2026-01-31 19:25:16'),
(3728, 'LLO', NULL, 'Palopo Lagaligo Airport', NULL, 'ID', 'Sulawesi Selatan', -3.0830000, 120.2450000, 'active', '2026-01-31 19:25:16', '2026-01-31 19:25:16'),
(3729, 'MOH', NULL, 'Maleo Airport', NULL, 'ID', 'Sulawesi Selatan', -2.2033300, 121.6600000, 'active', '2026-01-31 19:25:17', '2026-01-31 19:25:17'),
(3730, 'MXB', 'WAWM', 'Andi Jemma Airport', NULL, 'ID', 'Sulawesi Selatan', -2.5580300, 120.3240000, 'active', '2026-01-31 19:25:17', '2026-01-31 19:25:17'),
(3731, 'SQR', 'WAWS', 'Soroako Airport', NULL, 'ID', 'Sulawesi Selatan', -2.5312000, 121.3580000, 'active', '2026-01-31 19:25:17', '2026-01-31 19:25:17'),
(3732, 'TRT', NULL, 'Toraja Airport', NULL, 'ID', 'Sulawesi Selatan', -3.1851000, 119.9164000, 'active', '2026-01-31 19:25:18', '2026-01-31 19:25:18'),
(3733, 'UPG', 'WAAA', 'Sultan Hasanuddin International Airport', NULL, 'ID', 'Sulawesi Selatan', -5.0616300, 119.5540000, 'active', '2026-01-31 19:25:18', '2026-01-31 19:25:18'),
(3734, 'LUW', 'WAMW', 'Syukuran Aminuddin Amir Airport', NULL, 'ID', 'Sulawesi Tengah', -1.0389200, 122.7720000, 'active', '2026-01-31 19:25:18', '2026-01-31 19:25:18'),
(3735, 'PLW', 'WAFF', 'Mutiara Airport', NULL, 'ID', 'Sulawesi Tengah', -0.9185420, 119.9100000, 'active', '2026-01-31 19:25:19', '2026-01-31 19:25:19'),
(3736, 'PSJ', 'WAMP', 'Kasiguncu Airport', NULL, 'ID', 'Sulawesi Tengah', -1.4167500, 120.6580000, 'active', '2026-01-31 19:25:19', '2026-01-31 19:25:19'),
(3737, 'TLI', 'WAMI', 'Sultan Bantilan Airport (Lalos Airport)', NULL, 'ID', 'Sulawesi Tengah', 1.1234300, 120.7940000, 'active', '2026-01-31 19:25:19', '2026-01-31 19:25:19'),
(3738, 'BUW', 'WAWB', 'Betoambari Airport', NULL, 'ID', 'Sulawesi Tenggara', -5.4868800, 122.5690000, 'active', '2026-01-31 19:25:20', '2026-01-31 19:25:20'),
(3739, 'KDI', 'WAWW', 'Wolter Monginsidi Airport', NULL, 'ID', 'Sulawesi Tenggara', -4.0816100, 122.4180000, 'active', '2026-01-31 19:25:20', '2026-01-31 19:25:20'),
(3740, 'KXB', 'WAWP', 'Sangia Nibandera Airport', NULL, 'ID', 'Sulawesi Tenggara', -4.3420000, 121.5214000, 'active', '2026-01-31 19:25:20', '2026-01-31 19:25:20'),
(3741, 'PUM', 'WAWP', 'Kolaka Pomala Airport', NULL, 'ID', 'Sulawesi Tenggara', -4.1810900, 121.6180000, 'active', '2026-01-31 19:25:21', '2026-01-31 19:25:21'),
(3742, 'RAQ', 'WAWR', 'Sugimanuru Airport', NULL, 'ID', 'Sulawesi Tenggara', -4.7605600, 122.5690000, 'active', '2026-01-31 19:25:22', '2026-01-31 19:25:22'),
(3743, 'TQQ', 'WA44', 'Maranggo Airport', NULL, 'ID', 'Sulawesi Tenggara', -5.7645700, 123.9170000, 'active', '2026-01-31 19:25:22', '2026-01-31 19:25:22'),
(3744, 'AEG', 'WIME', 'Aek Godang Airport', NULL, 'ID', 'Sulawesi Utara', 1.4001000, 99.4305000, 'active', '2026-01-31 19:25:23', '2026-01-31 19:25:23'),
(3745, 'BJG', NULL, 'Kotamobagu Mopait Airport', NULL, 'ID', 'Sulawesi Utara', -0.9728960, 122.1450000, 'active', '2026-01-31 19:25:23', '2026-01-31 19:25:23'),
(3746, 'DTB', 'WIMN', 'Silangit Airport', NULL, 'ID', 'Sulawesi Utara', 2.2597300, 98.9919000, 'active', '2026-01-31 19:25:23', '2026-01-31 19:25:23'),
(3747, 'FLZ', 'WIMS', 'Ferdinand Lumban Tobing Airport', NULL, 'ID', 'Sulawesi Utara', 1.5559400, 98.8889000, 'active', '2026-01-31 19:25:24', '2026-01-31 19:25:24'),
(3748, 'GNS', 'WIMB', 'Binaka Airport', NULL, 'ID', 'Sulawesi Utara', 1.1663800, 97.7047000, 'active', '2026-01-31 19:25:24', '2026-01-31 19:25:24'),
(3749, 'KNO', 'WIMM', 'Kualanamu International Airport', NULL, 'ID', 'Sulawesi Utara', 3.6422200, 98.8853000, 'active', '2026-01-31 19:25:24', '2026-01-31 19:25:24'),
(3750, 'MDC', 'WAMM', 'Sam Ratulangi International Airport', NULL, 'ID', 'Sulawesi Utara', 1.5492600, 124.9260000, 'active', '2026-01-31 19:25:25', '2026-01-31 19:25:25'),
(3751, 'MES', 'WIMK', 'Soewondo Air Force Base', NULL, 'ID', 'Sulawesi Utara', 3.5591700, 98.6711000, 'active', '2026-01-31 19:25:25', '2026-01-31 19:25:25'),
(3752, 'MNA', 'WAMN', 'Melangguane Airport', NULL, 'ID', 'Sulawesi Utara', 4.0069400, 126.6730000, 'active', '2026-01-31 19:25:25', '2026-01-31 19:25:25'),
(3753, 'NAH', 'WAMH', 'Naha Airport', NULL, 'ID', 'Sulawesi Utara', 3.6832100, 125.5280000, 'active', '2026-01-31 19:25:26', '2026-01-31 19:25:26'),
(3754, 'SIW', 'WIMP', 'Sibisa Airport', NULL, 'ID', 'Sulawesi Utara', 2.6666700, 98.9333000, 'active', '2026-01-31 19:25:26', '2026-01-31 19:25:26'),
(3755, 'PDG', 'WIPT', 'Minangkabau International Airport', NULL, 'ID', 'Sumatera Barat', -0.7869170, 100.2810000, 'active', '2026-01-31 19:25:26', '2026-01-31 19:25:26'),
(3756, 'PPR', 'WIDE', 'Tuanku Tambusai Airport', NULL, 'ID', 'Sumatera Barat', 0.8454310, 100.3700000, 'active', '2026-01-31 19:25:27', '2026-01-31 19:25:27'),
(3757, 'RKI', 'WIBR', 'Rokot Airport', NULL, 'ID', 'Sumatera Barat', -0.9500000, 100.7500000, 'active', '2026-01-31 19:25:27', '2026-01-31 19:25:27'),
(3758, 'KLQ', 'WIPV', 'Keluang Airport', NULL, 'ID', 'Sumatera Selatan', -2.6235300, 103.9550000, 'active', '2026-01-31 19:25:27', '2026-01-31 19:25:27'),
(3759, 'PDO', 'WIPQ', 'Pendopo Airport', NULL, 'ID', 'Sumatera Selatan', -3.2860700, 103.8800000, 'active', '2026-01-31 19:25:28', '2026-01-31 19:25:28'),
(3760, 'PLM', 'WIPP', 'Sultan Mahmud Badaruddin II International Airport', NULL, 'ID', 'Sumatera Selatan', -2.8982500, 104.7000000, 'active', '2026-01-31 19:25:28', '2026-01-31 19:25:28'),
(3761, 'AMI', 'WADA', 'Selaparang Airport', NULL, 'ID', 'West Nusa Tenggara', -8.5605600, 116.0940000, 'active', '2026-01-31 19:25:28', '2026-01-31 19:25:28'),
(3762, 'AYW', 'WASA', 'Ayawasi Airport', NULL, 'ID', 'West Papua', -1.1593000, 132.4630000, 'active', '2026-01-31 19:25:29', '2026-01-31 19:25:29'),
(3763, 'JOG', 'WIIJ', 'Adisucipto International Airport', NULL, 'ID', 'Yogyakarta', -7.7881800, 110.4320000, 'active', '2026-01-31 19:25:29', '2026-01-31 19:25:29'),
(3764, 'SNN', 'EINN', 'Shannon Airport', NULL, 'IE', 'Clare', 52.7020000, -8.9248200, 'active', '2026-01-31 19:25:29', '2026-01-31 19:25:29'),
(3765, 'BYT', 'EIBN', 'Bantry Aerodrome', NULL, 'IE', 'Cork', 51.6686000, -9.4841700, 'active', '2026-01-31 19:25:30', '2026-01-31 19:25:30'),
(3766, 'ORK', 'EICK', 'Cork Airport', NULL, 'IE', 'Cork', 51.8413000, -8.4911100, 'active', '2026-01-31 19:25:30', '2026-01-31 19:25:30'),
(3767, 'CFN', 'EIDL', 'Donegal Airport', NULL, 'IE', 'Donegal', 55.0442000, -8.3410000, 'active', '2026-01-31 19:25:30', '2026-01-31 19:25:30'),
(3768, 'LTR', 'EILT', 'Letterkenny Airfield', NULL, 'IE', 'Donegal', 54.9513000, -7.6728300, 'active', '2026-01-31 19:25:31', '2026-01-31 19:25:31'),
(3769, 'DUB', 'EIDW', 'Dublin Airport', NULL, 'IE', 'Dublin', 53.4213000, -6.2700700, 'active', '2026-01-31 19:25:31', '2026-01-31 19:25:31'),
(3770, 'GWY', 'EICM', 'Galway Airport', NULL, 'IE', 'Galway', 53.3002000, -8.9415900, 'active', '2026-01-31 19:25:31', '2026-01-31 19:25:31'),
(3771, 'IIA', 'EIMN', 'Inishmaan Aerodrome', NULL, 'IE', 'Galway', 53.0930000, -9.5680600, 'active', '2026-01-31 19:25:32', '2026-01-31 19:25:32'),
(3772, 'INQ', 'EIIR', 'Inisheer Aerodrome', NULL, 'IE', 'Galway', 53.0647000, -9.5109000, 'active', '2026-01-31 19:25:32', '2026-01-31 19:25:32'),
(3773, 'IOR', 'EIIM', 'Inishmore Aerodrome (Kilronan Airport)', NULL, 'IE', 'Galway', 53.1067000, -9.6536100, 'active', '2026-01-31 19:25:32', '2026-01-31 19:25:32'),
(3774, 'NNR', 'EICA', 'Connemara Airport', NULL, 'IE', 'Galway', 53.2303000, -9.4677800, 'active', '2026-01-31 19:25:33', '2026-01-31 19:25:33'),
(3775, 'KIR', 'EIKY', 'Kerry Airport (Farranfore Airport)', NULL, 'IE', 'Kerry', 52.1809000, -9.5237800, 'active', '2026-01-31 19:25:33', '2026-01-31 19:25:33'),
(3776, 'KKY', 'EIKK', 'Kilkenny Airport', NULL, 'IE', 'Kilkenny', 52.6508000, -7.2961100, 'active', '2026-01-31 19:25:33', '2026-01-31 19:25:33'),
(3777, 'BLY', 'EIBT', 'Belmullet Aerodrome', NULL, 'IE', 'Mayo', 54.2228000, -10.0308000, 'active', '2026-01-31 19:25:34', '2026-01-31 19:25:34'),
(3778, 'NOC', 'EIKN', 'Ireland West Airport Knock', NULL, 'IE', 'Mayo', 53.9103000, -8.8184900, 'active', '2026-01-31 19:25:34', '2026-01-31 19:25:34'),
(3779, 'SXL', 'EISG', 'Sligo Airport', NULL, 'IE', 'Sligo', 54.2802000, -8.5992100, 'active', '2026-01-31 19:25:34', '2026-01-31 19:25:34'),
(3780, 'WAT', 'EIWF', 'Waterford Airport', NULL, 'IE', 'Waterford', 52.1872000, -7.0869600, 'active', '2026-01-31 19:25:35', '2026-01-31 19:25:35'),
(3781, 'BEV', 'LLBS', 'Beersheba Airport', NULL, 'IL', 'HaDarom', 31.2870000, 34.7230000, 'active', '2026-01-31 19:25:35', '2026-01-31 19:25:35'),
(3782, 'EIY', 'LLEY', 'Ein Yahav Airfield', NULL, 'IL', 'HaDarom', 30.6217000, 35.2033000, 'active', '2026-01-31 19:25:35', '2026-01-31 19:25:35'),
(3783, 'ETH', 'LLET', 'J. Hozman Airport', NULL, 'IL', 'HaDarom', 29.5613000, 34.9601000, 'active', '2026-01-31 19:25:36', '2026-01-31 19:25:36'),
(3784, 'ETM', 'LLER', 'Ramon Airport', NULL, 'IL', 'HaDarom', 29.7237000, 35.0114000, 'active', '2026-01-31 19:25:36', '2026-01-31 19:25:36'),
(3785, 'MIP', 'LLMR', 'Mitzpe Ramon Airport', NULL, 'IL', 'HaDarom', 30.7761000, 34.6667000, 'active', '2026-01-31 19:25:37', '2026-01-31 19:25:37'),
(3786, 'MTZ', 'LLMZ', 'Bar Yehuda Airfield (Masada Airfield)', NULL, 'IL', 'HaDarom', 31.3282000, 35.3886000, 'active', '2026-01-31 19:25:38', '2026-01-31 19:25:38'),
(3787, 'VDA', 'LLOV', 'Ovda Airport', NULL, 'IL', 'HaDarom', 29.9403000, 34.9358000, 'active', '2026-01-31 19:25:38', '2026-01-31 19:25:38'),
(3788, 'VTM', 'LLNV', 'Nevatim Airbase', NULL, 'IL', 'HaDarom', 31.2083000, 35.0123000, 'active', '2026-01-31 19:25:38', '2026-01-31 19:25:38'),
(3789, 'YOT', 'LLYT', 'Yotvata Airfield', NULL, 'IL', 'HaDarom', 29.9011000, 35.0675000, 'active', '2026-01-31 19:25:39', '2026-01-31 19:25:39'),
(3790, 'KSW', 'LLKS', 'Kiryat Shmona Airport', NULL, 'IL', 'HaTsafon', 33.2167000, 35.6000000, 'active', '2026-01-31 19:25:39', '2026-01-31 19:25:39'),
(3791, 'RPN', 'LLIB', 'Rosh Pina Airport', NULL, 'IL', 'HaTsafon', 32.9810000, 35.5719000, 'active', '2026-01-31 19:25:39', '2026-01-31 19:25:39'),
(3792, 'HFA', 'LLHA', 'Haifa Airport (Uri Michaeli Airport)', NULL, 'IL', 'Hefa', 32.8094000, 35.0431000, 'active', '2026-01-31 19:25:40', '2026-01-31 19:25:40'),
(3793, 'SDV', 'LLSD', 'Sde Dov Airport', NULL, 'IL', 'Tel Aviv', 32.1147000, 34.7822000, 'active', '2026-01-31 19:25:40', '2026-01-31 19:25:40'),
(3794, 'TLV', 'LLBG', 'Ben Gurion Airport', NULL, 'IL', 'Tel Aviv', 32.0114000, 34.8867000, 'active', '2026-01-31 19:25:40', '2026-01-31 19:25:40'),
(3795, 'JRS', 'OJJR', 'Atarot Airport (Jerusalem International Airport)', NULL, 'IL', 'Yerushalayim', 31.8647000, 35.2192000, 'active', '2026-01-31 19:25:41', '2026-01-31 19:25:41'),
(3796, 'CBD', 'VOCX', 'Car Nicobar Air Force Base', NULL, 'IN', 'Andaman and Nicobar Islands', 9.1525100, 92.8196000, 'active', '2026-01-31 19:25:41', '2026-01-31 19:25:41'),
(3797, 'IXZ', 'VOPB', 'Veer Savarkar International Airport (Port Blair Airport)', NULL, 'IN', 'Andaman and Nicobar Islands', 11.6412000, 92.7297000, 'active', '2026-01-31 19:25:41', '2026-01-31 19:25:41'),
(3798, 'BEK', 'VIBY', 'Bareilly Airport', NULL, 'IN', 'Andhra Pradesh', 28.4221000, 79.4508000, 'active', '2026-01-31 19:25:42', '2026-01-31 19:25:42'),
(3799, 'CDP', 'VOCP', 'Kadapa Airport', NULL, 'IN', 'Andhra Pradesh', 14.5100000, 78.7728000, 'active', '2026-01-31 19:25:42', '2026-01-31 19:25:42'),
(3800, 'KJB', 'VOKU', 'Kurnool Airport', NULL, 'IN', 'Andhra Pradesh', 15.7132000, 78.1612000, 'active', '2026-01-31 19:25:42', '2026-01-31 19:25:42'),
(3801, 'PUT', 'VOPN', 'Sri Sathya Sai Airport', NULL, 'IN', 'Andhra Pradesh', 14.1493000, 77.7911000, 'active', '2026-01-31 19:25:43', '2026-01-31 19:25:43'),
(3802, 'RJA', 'VORY', 'Rajahmundry Airport', NULL, 'IN', 'Andhra Pradesh', 17.1104000, 81.8182000, 'active', '2026-01-31 19:25:43', '2026-01-31 19:25:43'),
(3803, 'TIR', 'VOTP', 'Tirupati Airport', NULL, 'IN', 'Andhra Pradesh', 13.6325000, 79.5433000, 'active', '2026-01-31 19:25:43', '2026-01-31 19:25:43'),
(3804, 'VGA', 'VOBZ', 'Vijayawada Airport', NULL, 'IN', 'Andhra Pradesh', 16.5304000, 80.7968000, 'active', '2026-01-31 19:25:44', '2026-01-31 19:25:44'),
(3805, 'VTZ', 'VEVZ', 'Visakhapatnam Airport', NULL, 'IN', 'Andhra Pradesh', 17.7212000, 83.2245000, 'active', '2026-01-31 19:25:44', '2026-01-31 19:25:44'),
(3806, 'IXT', 'VEPG', 'Pasighat Airport', NULL, 'IN', 'Arunachal Pradesh', 28.0661000, 95.3356000, 'active', '2026-01-31 19:25:44', '2026-01-31 19:25:44'),
(3807, 'IXV', 'VEAN', 'Along Airport', NULL, 'IN', 'Arunachal Pradesh', 28.1753000, 94.8020000, 'active', '2026-01-31 19:25:45', '2026-01-31 19:25:45'),
(3808, 'TEI', 'VETJ', 'Tezu Airport', NULL, 'IN', 'Arunachal Pradesh', 27.9412000, 96.1344000, 'active', '2026-01-31 19:25:45', '2026-01-31 19:25:45'),
(3809, 'ZER', 'VEZO', 'Zero Airport (Ziro Airport)', NULL, 'IN', 'Arunachal Pradesh', 27.5883000, 93.8281000, 'active', '2026-01-31 19:25:45', '2026-01-31 19:25:45'),
(3810, 'DEP', 'VEDZ', 'Daporijo Airport', NULL, 'IN', 'Assam', 27.9855000, 94.2228000, 'active', '2026-01-31 19:25:46', '2026-01-31 19:25:46'),
(3811, 'DIB', 'VEMN', 'Dibrugarh Airport (Mohanbari Airport)', NULL, 'IN', 'Assam', 27.4839000, 95.0169000, 'active', '2026-01-31 19:25:46', '2026-01-31 19:25:46'),
(3812, 'GAU', 'VEGT', 'Lokpriya Gopinath Bordoloi International Airport', NULL, 'IN', 'Assam', 26.1061000, 91.5859000, 'active', '2026-01-31 19:25:46', '2026-01-31 19:25:46'),
(3813, 'IXI', 'VELR', 'Lilabari Airport', NULL, 'IN', 'Assam', 27.2955000, 94.0976000, 'active', '2026-01-31 19:25:47', '2026-01-31 19:25:47'),
(3814, 'IXN', 'VEKW', 'Khowai Airport', NULL, 'IN', 'Assam', 24.0619000, 91.6039000, 'active', '2026-01-31 19:25:47', '2026-01-31 19:25:47'),
(3815, 'IXQ', 'VEKM', 'Kamalpur Airport', NULL, 'IN', 'Assam', 24.1317000, 91.8142000, 'active', '2026-01-31 19:25:47', '2026-01-31 19:25:47'),
(3816, 'IXS', 'VEKU', 'Silchar Airport (Kumbhirgram Air Force Base)', NULL, 'IN', 'Assam', 24.9129000, 92.9787000, 'active', '2026-01-31 19:25:48', '2026-01-31 19:25:48'),
(3817, 'JRH', 'VEJT', 'Jorhat Airport (Rowriah Airport)', NULL, 'IN', 'Assam', 26.7315000, 94.1755000, 'active', '2026-01-31 19:25:48', '2026-01-31 19:25:48'),
(3818, 'RUP', 'VERU', 'Rupsi Airport', NULL, 'IN', 'Assam', 26.1397000, 89.9100000, 'active', '2026-01-31 19:25:48', '2026-01-31 19:25:48'),
(3819, 'TEZ', 'VETZ', 'Tezpur Airport', NULL, 'IN', 'Assam', 26.7091000, 92.7847000, 'active', '2026-01-31 19:25:49', '2026-01-31 19:25:49'),
(3820, 'DBR', 'VEDH', 'Darbhanga Airport', NULL, 'IN', 'Bihar', 26.1947000, 85.9175000, 'active', '2026-01-31 19:25:49', '2026-01-31 19:25:49'),
(3821, 'GAY', 'VEGY', 'Gaya Airport (Bodhgaya Airport)', NULL, 'IN', 'Bihar', 24.7443000, 84.9512000, 'active', '2026-01-31 19:25:49', '2026-01-31 19:25:49'),
(3822, 'MZU', 'VEMZ', 'Muzaffarpur Airport', NULL, 'IN', 'Bihar', 26.1191000, 85.3137000, 'active', '2026-01-31 19:25:50', '2026-01-31 19:25:50'),
(3823, 'PAT', 'VEPT', 'Lok Nayak Jayaprakash Airport', NULL, 'IN', 'Bihar', 25.5913000, 85.0880000, 'active', '2026-01-31 19:25:50', '2026-01-31 19:25:50'),
(3824, 'PXN', 'VEPU', 'Purnea Airport', NULL, 'IN', 'Bihar', 25.4535000, 87.2436000, 'active', '2026-01-31 19:25:50', '2026-01-31 19:25:50'),
(3825, 'IXC', 'VICG', 'Chandigarh Airport', NULL, 'IN', 'Chandigarh', 30.6735000, 76.7885000, 'active', '2026-01-31 19:25:51', '2026-01-31 19:25:51'),
(3826, 'JGB', NULL, 'Jagdalpur Airport', NULL, 'IN', 'Chhattisgarh', 19.0743000, 82.0368000, 'active', '2026-01-31 19:25:51', '2026-01-31 19:25:51'),
(3827, 'PAB', 'VEBU', 'Bilaspur Airport', NULL, 'IN', 'Chhattisgarh', 21.9884000, 82.1110000, 'active', '2026-01-31 19:25:51', '2026-01-31 19:25:51'),
(3828, 'RPR', 'VARP', 'Swami Vivekananda Airport', NULL, 'IN', 'Chhattisgarh', 21.1804000, 81.7388000, 'active', '2026-01-31 19:25:52', '2026-01-31 19:25:52'),
(3829, 'DIU', NULL, 'Diu Airport', NULL, 'IN', 'Daman and Diu', 20.7131000, 70.9211000, 'active', '2026-01-31 19:25:52', '2026-01-31 19:25:52'),
(3830, 'NMB', 'VADN', 'Daman Airport', NULL, 'IN', 'Daman and Diu', 20.4344000, 72.8432000, 'active', '2026-01-31 19:25:52', '2026-01-31 19:25:52'),
(3831, 'DEL', 'VIDP', 'Indira Gandhi International Airport', NULL, 'IN', 'Delhi', 28.5665000, 77.1031000, 'active', '2026-01-31 19:25:53', '2026-01-31 19:25:53'),
(3832, 'GOI', 'VOGO', 'Goa International Airport (Dabolim Airport)', NULL, 'IN', 'Goa', 15.3808000, 73.8314000, 'active', '2026-01-31 19:25:53', '2026-01-31 19:25:53'),
(3833, 'GOX', 'VOGA', 'Manohar International Airport (Goa)', NULL, 'IN', 'Goa', 15.7312000, 73.8666000, 'active', '2026-01-31 19:25:53', '2026-01-31 19:25:53'),
(3834, 'AMD', 'VAAH', 'Sardar Vallabhbhai Patel International Airport', NULL, 'IN', 'Gujarat', 23.0772000, 72.6347000, 'active', '2026-01-31 19:25:54', '2026-01-31 19:25:54'),
(3835, 'BDQ', 'VABO', 'Vadodara Airport (Civil Airport Harni)', NULL, 'IN', 'Gujarat', 22.3362000, 73.2263000, 'active', '2026-01-31 19:25:54', '2026-01-31 19:25:54'),
(3836, 'BHJ', 'VABJ', 'Bhuj Airport / Bhuj Rudra Mata Air Force Base', NULL, 'IN', 'Gujarat', 23.2878000, 69.6702000, 'active', '2026-01-31 19:25:54', '2026-01-31 19:25:54'),
(3837, 'BHU', 'VABV', 'Bhavnagar Airport', NULL, 'IN', 'Gujarat', 21.7522000, 72.1852000, 'active', '2026-01-31 19:25:55', '2026-01-31 19:25:55'),
(3838, 'HSR', 'VAHS', 'Rajkot International Airport', NULL, 'IN', 'Gujarat', 22.3813000, 71.0319000, 'active', '2026-01-31 19:25:55', '2026-01-31 19:25:55'),
(3839, 'IXK', 'VAKS', 'Keshod Airport', NULL, 'IN', 'Gujarat', 21.3171000, 70.2704000, 'active', '2026-01-31 19:25:55', '2026-01-31 19:25:55'),
(3840, 'IXY', 'VAKE', 'Kandla Airport (Gandhidham Airport)', NULL, 'IN', 'Gujarat', 23.1127000, 70.1003000, 'active', '2026-01-31 19:25:56', '2026-01-31 19:25:56'),
(3841, 'JGA', 'VAJM', 'Jamnagar Airport (Govardhanpur Airport)', NULL, 'IN', 'Gujarat', 22.4655000, 70.0126000, 'active', '2026-01-31 19:25:56', '2026-01-31 19:25:56'),
(3842, 'PBD', 'VAPR', 'Porbandar Airport', NULL, 'IN', 'Gujarat', 21.6487000, 69.6572000, 'active', '2026-01-31 19:25:56', '2026-01-31 19:25:56'),
(3843, 'RAJ', 'VARK', 'Rajkot Airport', NULL, 'IN', 'Gujarat', 22.3092000, 70.7795000, 'active', '2026-01-31 19:25:57', '2026-01-31 19:25:57'),
(3844, 'STV', 'VASU', 'Surat Airport', NULL, 'IN', 'Gujarat', 21.1141000, 72.7418000, 'active', '2026-01-31 19:25:57', '2026-01-31 19:25:57'),
(3845, 'HSS', 'VIHR', 'Hisar Airport', NULL, 'IN', 'Haryana', 29.1794000, 75.7553000, 'active', '2026-01-31 19:25:57', '2026-01-31 19:25:57'),
(3846, 'DHM', 'VIGG', 'Gaggal Airport', NULL, 'IN', 'Himachal Pradesh', 32.1651000, 76.2634000, 'active', '2026-01-31 19:25:58', '2026-01-31 19:25:58'),
(3847, 'KUU', 'VIBR', 'Bhuntar Airport (Kullu Manali Airport)', NULL, 'IN', 'Himachal Pradesh', 31.8767000, 77.1544000, 'active', '2026-01-31 19:25:58', '2026-01-31 19:25:58'),
(3848, 'SLV', 'VISM', 'Shimla Airport', NULL, 'IN', 'Himachal Pradesh', 31.0818000, 77.0680000, 'active', '2026-01-31 19:25:59', '2026-01-31 19:25:59'),
(3849, 'IXJ', 'VIJU', 'Jammu Airport (Satwari Airport)', NULL, 'IN', 'Jammu and Kashmir', 32.6891000, 74.8374000, 'active', '2026-01-31 19:26:00', '2026-01-31 19:26:00'),
(3850, 'IXL', 'VILH', 'Kushok Bakula Rimpochee Airport', NULL, 'IN', 'Jammu and Kashmir', 34.1359000, 77.5465000, 'active', '2026-01-31 19:26:00', '2026-01-31 19:26:00'),
(3851, 'RJI', NULL, 'Rajauri Airport', NULL, 'IN', 'Jammu and Kashmir', 33.3779000, 74.3152000, 'active', '2026-01-31 19:26:00', '2026-01-31 19:26:00'),
(3852, 'SXR', 'VISR', 'Sheikh ul Alam International Airport', NULL, 'IN', 'Jammu and Kashmir', 33.9871000, 74.7742000, 'active', '2026-01-31 19:26:01', '2026-01-31 19:26:01'),
(3853, 'DBD', 'VEDB', 'Dhanbad Airport', NULL, 'IN', 'Jharkhand', 23.8340000, 86.4253000, 'active', '2026-01-31 19:26:01', '2026-01-31 19:26:01'),
(3854, 'DGH', 'VEDO', 'Deoghar Airport', NULL, 'IN', 'Jharkhand', 24.4433000, 86.7065000, 'active', '2026-01-31 19:26:01', '2026-01-31 19:26:01'),
(3855, 'IXR', 'VERC', 'Birsa Munda Airport', NULL, 'IN', 'Jharkhand', 23.3143000, 85.3217000, 'active', '2026-01-31 19:26:02', '2026-01-31 19:26:02'),
(3856, 'IXW', 'VEJS', 'Sonari Airport', NULL, 'IN', 'Jharkhand', 22.8132000, 86.1688000, 'active', '2026-01-31 19:26:02', '2026-01-31 19:26:02'),
(3857, 'BEP', 'VOBI', 'Bellary Airport', NULL, 'IN', 'Karnataka', 15.1628000, 76.8828000, 'active', '2026-01-31 19:26:02', '2026-01-31 19:26:02'),
(3858, 'BLR', 'VOBL', 'Kempegowda International Airport', NULL, 'IN', 'Karnataka', 13.1979000, 77.7063000, 'active', '2026-01-31 19:26:03', '2026-01-31 19:26:03'),
(3859, 'HBX', 'VAHB', 'Hubli Airport', NULL, 'IN', 'Karnataka', 15.3617000, 75.0849000, 'active', '2026-01-31 19:26:03', '2026-01-31 19:26:03'),
(3860, 'IXE', 'VOML', 'Mangalore Airport', NULL, 'IN', 'Karnataka', 12.9613000, 74.8901000, 'active', '2026-01-31 19:26:03', '2026-01-31 19:26:03'),
(3861, 'IXG', 'VABM', 'Belgaum Airport', NULL, 'IN', 'Karnataka', 15.8593000, 74.6183000, 'active', '2026-01-31 19:26:04', '2026-01-31 19:26:04'),
(3862, 'MYQ', 'VOMY', 'Mysore Airport (Mandakalli Airport)', NULL, 'IN', 'Karnataka', 12.2300000, 76.6558000, 'active', '2026-01-31 19:26:04', '2026-01-31 19:26:04'),
(3863, 'RQY', NULL, 'Shivamogga Rashtrakavi Kuvempu Airport', NULL, 'IN', 'Karnataka', 13.8577000, 75.6054000, 'active', '2026-01-31 19:26:04', '2026-01-31 19:26:04'),
(3864, 'VDY', 'VOJV', 'Vidyanagar Airport (Jindal Airport)', NULL, 'IN', 'Karnataka', 15.1750000, 76.6349000, 'active', '2026-01-31 19:26:05', '2026-01-31 19:26:05'),
(3865, 'CCJ', 'VOCL', 'Calicut International Airport', NULL, 'IN', 'Kerala', 11.1368000, 75.9553000, 'active', '2026-01-31 19:26:05', '2026-01-31 19:26:05'),
(3866, 'CNN', 'VOKN', 'Kannur International Airport', NULL, 'IN', 'Kerala', 11.9186000, 75.5472000, 'active', '2026-01-31 19:26:05', '2026-01-31 19:26:05'),
(3867, 'COK', 'VOCI', 'Cochin International Airport (Nedumbassery Airport)', NULL, 'IN', 'Kerala', 10.1520000, 76.4019000, 'active', '2026-01-31 19:26:06', '2026-01-31 19:26:06'),
(3868, 'TRV', 'VOTV', 'Trivandrum International Airport', NULL, 'IN', 'Kerala', 8.4821200, 76.9201000, 'active', '2026-01-31 19:26:06', '2026-01-31 19:26:06'),
(3869, 'AGX', 'VOAT', 'Agatti Aerodrome', NULL, 'IN', 'Lakshadweep', 10.8237000, 72.1760000, 'active', '2026-01-31 19:26:06', '2026-01-31 19:26:06'),
(3870, 'BHO', 'VABP', 'Raja Bhoj Airport', NULL, 'IN', 'Madhya Pradesh', 23.2875000, 77.3374000, 'active', '2026-01-31 19:26:07', '2026-01-31 19:26:07'),
(3871, 'GUX', 'VAGN', 'Guna Airport', NULL, 'IN', 'Madhya Pradesh', 24.6547000, 77.3473000, 'active', '2026-01-31 19:26:07', '2026-01-31 19:26:07'),
(3872, 'GWL', 'VIGR', 'Rajmata Vijaya Raje Scindia Airport (Gwalior Airport)', NULL, 'IN', 'Madhya Pradesh', 26.2933000, 78.2278000, 'active', '2026-01-31 19:26:07', '2026-01-31 19:26:07'),
(3873, 'HJR', 'VAKJ', 'Civil Aerodrome Khajuraho', NULL, 'IN', 'Madhya Pradesh', 24.8172000, 79.9186000, 'active', '2026-01-31 19:26:08', '2026-01-31 19:26:08'),
(3874, 'IDR', 'VAID', 'Devi Ahilyabai Holkar International Airport', NULL, 'IN', 'Madhya Pradesh', 22.7218000, 75.8011000, 'active', '2026-01-31 19:26:08', '2026-01-31 19:26:08');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(3875, 'JLR', 'VAJB', 'Jabalpur Airport (Dumna Airport)', NULL, 'IN', 'Madhya Pradesh', 23.1778000, 80.0520000, 'active', '2026-01-31 19:26:08', '2026-01-31 19:26:08'),
(3876, 'REW', NULL, 'Churhata Airport', NULL, 'IN', 'Madhya Pradesh', 24.5034000, 81.2203000, 'active', '2026-01-31 19:26:09', '2026-01-31 19:26:09'),
(3877, 'TNI', 'VIST', 'Satna Airport', NULL, 'IN', 'Madhya Pradesh', 24.5623000, 80.8549000, 'active', '2026-01-31 19:26:09', '2026-01-31 19:26:09'),
(3878, 'AKD', 'VAAK', 'Akola Airport', NULL, 'IN', 'Maharashtra', 20.6990000, 77.0586000, 'active', '2026-01-31 19:26:09', '2026-01-31 19:26:09'),
(3879, 'BOM', 'VABB', 'Chhatrapati Shivaji International Airport', NULL, 'IN', 'Maharashtra', 19.0887000, 72.8679000, 'active', '2026-01-31 19:26:10', '2026-01-31 19:26:10'),
(3880, 'GDB', NULL, 'Birsi Gondia Airport', NULL, 'IN', 'Maharashtra', 21.5220000, 80.2907000, 'active', '2026-01-31 19:26:10', '2026-01-31 19:26:10'),
(3881, 'ISK', 'VAOZ', 'Nashik Airport', NULL, 'IN', 'Maharashtra', 20.1191000, 73.9129000, 'active', '2026-01-31 19:26:11', '2026-01-31 19:26:11'),
(3882, 'IXU', 'VAAU', 'Aurangabad Airport (Chikkalthana Airport)', NULL, 'IN', 'Maharashtra', 19.8627000, 75.3981000, 'active', '2026-01-31 19:26:11', '2026-01-31 19:26:11'),
(3883, 'JLG', 'VAJL', 'Jalgaon Airport', NULL, 'IN', 'Maharashtra', 20.9614000, 75.6192000, 'active', '2026-01-31 19:26:12', '2026-01-31 19:26:12'),
(3884, 'KLH', 'VAKP', 'Kolhapur Airport', NULL, 'IN', 'Maharashtra', 16.6647000, 74.2894000, 'active', '2026-01-31 19:26:12', '2026-01-31 19:26:12'),
(3885, 'LTU', 'VALT', 'Latur Airport', NULL, 'IN', 'Maharashtra', 18.4115000, 76.4647000, 'active', '2026-01-31 19:26:13', '2026-01-31 19:26:13'),
(3886, 'NAG', 'VANP', 'Dr. Babasaheb Ambedkar International Airport', NULL, 'IN', 'Maharashtra', 21.0922000, 79.0472000, 'active', '2026-01-31 19:26:13', '2026-01-31 19:26:13'),
(3887, 'NDC', 'VAND', 'Shri Guru Gobind Singh Ji Airport', NULL, 'IN', 'Maharashtra', 19.1833000, 77.3167000, 'active', '2026-01-31 19:26:13', '2026-01-31 19:26:13'),
(3888, 'PNQ', 'VAPO', 'Pune Airport', NULL, 'IN', 'Maharashtra', 18.5821000, 73.9197000, 'active', '2026-01-31 19:26:14', '2026-01-31 19:26:14'),
(3889, 'RTC', 'VARG', 'Ratnagiri Airport', NULL, 'IN', 'Maharashtra', 17.0136000, 73.3278000, 'active', '2026-01-31 19:26:14', '2026-01-31 19:26:14'),
(3890, 'SAG', NULL, 'Shirdi Airport', NULL, 'IN', 'Maharashtra', 19.6886000, 74.3789000, 'active', '2026-01-31 19:26:14', '2026-01-31 19:26:14'),
(3891, 'SDW', NULL, 'Sindhudurg Airport', NULL, 'IN', 'Maharashtra', 15.9989000, 73.5342000, 'active', '2026-01-31 19:26:15', '2026-01-31 19:26:15'),
(3892, 'SSE', 'VASL', 'Solapur Airport', NULL, 'IN', 'Maharashtra', 17.6280000, 75.9348000, 'active', '2026-01-31 19:26:15', '2026-01-31 19:26:15'),
(3893, 'IMF', 'VEIM', 'Imphal International Airport (Tulihal Airport)', NULL, 'IN', 'Manipur', 24.7600000, 93.8967000, 'active', '2026-01-31 19:26:15', '2026-01-31 19:26:15'),
(3894, 'SHL', 'VEBI', 'Shillong Airport (Barapani Airport)', NULL, 'IN', 'Meghalaya', 25.7036000, 91.9787000, 'active', '2026-01-31 19:26:16', '2026-01-31 19:26:16'),
(3895, 'AJL', 'VELP', 'Lengpui Airport', NULL, 'IN', 'Mizoram', 23.8406000, 92.6197000, 'active', '2026-01-31 19:26:16', '2026-01-31 19:26:16'),
(3896, 'DMU', 'VEMR', 'Dimapur Airport', NULL, 'IN', 'Nagaland', 25.8839000, 93.7711000, 'active', '2026-01-31 19:26:16', '2026-01-31 19:26:16'),
(3897, 'BBI', 'VEBS', 'Biju Patnaik International Airport', NULL, 'IN', 'Odisha', 20.2444000, 85.8178000, 'active', '2026-01-31 19:26:17', '2026-01-31 19:26:17'),
(3898, 'JRG', 'VEJH', 'Veer Surendra Sai Jharsuguda Airport', NULL, 'IN', 'Odisha', 21.9159000, 84.0464000, 'active', '2026-01-31 19:26:17', '2026-01-31 19:26:17'),
(3899, 'JSA', 'VIJR', 'Jaisalmer Airport', NULL, 'IN', 'Odisha', 26.8887000, 70.8650000, 'active', '2026-01-31 19:26:17', '2026-01-31 19:26:17'),
(3900, 'PYB', 'VEJP', 'Jeypore Airport', NULL, 'IN', 'Odisha', 18.8800000, 82.5520000, 'active', '2026-01-31 19:26:18', '2026-01-31 19:26:18'),
(3901, 'RRK', 'VERK', 'Rourkela Airport', NULL, 'IN', 'Odisha', 22.2567000, 84.8146000, 'active', '2026-01-31 19:26:18', '2026-01-31 19:26:18'),
(3902, 'UKE', 'VEUK', 'Utkela Airport', NULL, 'IN', 'Odisha', 20.0976000, 83.1829000, 'active', '2026-01-31 19:26:18', '2026-01-31 19:26:18'),
(3903, 'PNY', 'VOPC', 'Puducherry Airport', NULL, 'IN', 'Puducherry', 11.9680000, 79.8120000, 'active', '2026-01-31 19:26:19', '2026-01-31 19:26:19'),
(3904, 'AIP', 'VIAX', 'Adampur Airport', NULL, 'IN', 'Punjab', 31.4331000, 75.7606000, 'active', '2026-01-31 19:26:19', '2026-01-31 19:26:19'),
(3905, 'ATQ', 'VIAR', 'Sri Guru Ram Dass Jee International Airport', NULL, 'IN', 'Punjab', 31.7096000, 74.7973000, 'active', '2026-01-31 19:26:19', '2026-01-31 19:26:19'),
(3906, 'BUP', 'VIBT', 'Bathinda Airport (Bhisiana Air Force Station)', NULL, 'IN', 'Punjab', 30.2701000, 74.7558000, 'active', '2026-01-31 19:26:20', '2026-01-31 19:26:20'),
(3907, 'IXP', 'VIPK', 'Pathankot Airport', NULL, 'IN', 'Punjab', 32.2336000, 75.6344000, 'active', '2026-01-31 19:26:21', '2026-01-31 19:26:21'),
(3908, 'LUH', 'VILD', 'Sahnewal Airport (Ludhiana Airport)', NULL, 'IN', 'Punjab', 30.8547000, 75.9526000, 'active', '2026-01-31 19:26:21', '2026-01-31 19:26:21'),
(3909, 'BKB', 'VIBK', 'Nal Airport', NULL, 'IN', 'Rajasthan', 28.0706000, 73.2072000, 'active', '2026-01-31 19:26:21', '2026-01-31 19:26:21'),
(3910, 'JAI', 'VIJP', 'Jaipur International Airport', NULL, 'IN', 'Rajasthan', 26.8242000, 75.8122000, 'active', '2026-01-31 19:26:22', '2026-01-31 19:26:22'),
(3911, 'JDH', 'VIJO', 'Jodhpur Airport', NULL, 'IN', 'Rajasthan', 26.2511000, 73.0489000, 'active', '2026-01-31 19:26:22', '2026-01-31 19:26:22'),
(3912, 'KQH', 'VIKG', 'Ajmer Kishangarh Airport', NULL, 'IN', 'Rajasthan', 26.6015000, 74.8141000, 'active', '2026-01-31 19:26:22', '2026-01-31 19:26:22'),
(3913, 'KTU', 'VIKO', 'Kota Airport', NULL, 'IN', 'Rajasthan', 25.1602000, 75.8456000, 'active', '2026-01-31 19:26:23', '2026-01-31 19:26:23'),
(3914, 'UDR', 'VAUD', 'Maharana Pratap Airport', NULL, 'IN', 'Rajasthan', 24.6177000, 73.8961000, 'active', '2026-01-31 19:26:23', '2026-01-31 19:26:23'),
(3915, 'PYG', NULL, 'Pakyong Airport', NULL, 'IN', 'Sikkim', 27.2266000, 88.5875000, 'active', '2026-01-31 19:26:23', '2026-01-31 19:26:23'),
(3916, 'CJB', 'VOCB', 'Coimbatore International Airport', NULL, 'IN', 'Tamil Nadu', 11.0300000, 77.0434000, 'active', '2026-01-31 19:26:24', '2026-01-31 19:26:24'),
(3917, 'IXM', 'VOMD', 'Madurai Airport', NULL, 'IN', 'Tamil Nadu', 9.8345100, 78.0934000, 'active', '2026-01-31 19:26:24', '2026-01-31 19:26:24'),
(3918, 'MAA', 'VOMM', 'Chennai International Airport', NULL, 'IN', 'Tamil Nadu', 12.9900000, 80.1693000, 'active', '2026-01-31 19:26:24', '2026-01-31 19:26:24'),
(3919, 'NVY', 'VONV', 'Neyveli Airport', NULL, 'IN', 'Tamil Nadu', 11.6130000, 79.5274000, 'active', '2026-01-31 19:26:25', '2026-01-31 19:26:25'),
(3920, 'SXV', 'VOSM', 'Salem Airport', NULL, 'IN', 'Tamil Nadu', 11.7833000, 78.0656000, 'active', '2026-01-31 19:26:25', '2026-01-31 19:26:25'),
(3921, 'TCR', 'VOTK', 'Tuticorin Airport', NULL, 'IN', 'Tamil Nadu', 8.7242400, 78.0258000, 'active', '2026-01-31 19:26:25', '2026-01-31 19:26:25'),
(3922, 'TJV', 'VOTJ', 'Thanjavur Air Force Station', NULL, 'IN', 'Tamil Nadu', 10.7224000, 79.1016000, 'active', '2026-01-31 19:26:26', '2026-01-31 19:26:26'),
(3923, 'TRZ', 'VOTR', 'Tiruchirappalli International Airport', NULL, 'IN', 'Tamil Nadu', 10.7654000, 78.7097000, 'active', '2026-01-31 19:26:26', '2026-01-31 19:26:26'),
(3924, 'BPM', 'VOHY', 'Begumpet Airport', NULL, 'IN', 'Telangana', 17.4531000, 78.4676000, 'active', '2026-01-31 19:26:26', '2026-01-31 19:26:26'),
(3925, 'HYD', 'VOHS', 'Rajiv Gandhi International Airport', NULL, 'IN', 'Telangana', 17.2313000, 78.4299000, 'active', '2026-01-31 19:26:27', '2026-01-31 19:26:27'),
(3926, 'RMD', 'VORG', 'Ramagundam Airport (Basanth Nagar Airport)', NULL, 'IN', 'Telangana', 18.7010000, 79.3923000, 'active', '2026-01-31 19:26:27', '2026-01-31 19:26:27'),
(3927, 'WGC', 'VOWA', 'Warangal Airport', NULL, 'IN', 'Telangana', 17.9144000, 79.6022000, 'active', '2026-01-31 19:26:27', '2026-01-31 19:26:27'),
(3928, 'IXA', 'VEAT', 'Agartala Airport (Singerbhil Airport)', NULL, 'IN', 'Tripura', 23.8870000, 91.2404000, 'active', '2026-01-31 19:26:28', '2026-01-31 19:26:28'),
(3929, 'IXH', 'VEKR', 'Kailashahar Airport', NULL, 'IN', 'Tripura', 24.3082000, 92.0072000, 'active', '2026-01-31 19:26:28', '2026-01-31 19:26:28'),
(3930, 'AGR', 'VIAG', 'Agra Airport', NULL, 'IN', 'Uttar Pradesh', 27.1558000, 77.9609000, 'active', '2026-01-31 19:26:28', '2026-01-31 19:26:28'),
(3931, 'AYJ', NULL, 'Ayodhya Faizabad Airport', NULL, 'IN', 'Uttar Pradesh', 26.7474000, 82.1505000, 'active', '2026-01-31 19:26:29', '2026-01-31 19:26:29'),
(3932, 'AZH', NULL, 'Azamgarh Airport', NULL, 'IN', 'Uttar Pradesh', 26.1615000, 83.1120000, 'active', '2026-01-31 19:26:29', '2026-01-31 19:26:29'),
(3933, 'CWK', NULL, 'Chitrakoot Airport', NULL, 'IN', 'Uttar Pradesh', 25.1690000, 80.9362000, 'active', '2026-01-31 19:26:29', '2026-01-31 19:26:29'),
(3934, 'GOP', 'VEGK', 'Gorakhpur Airport', NULL, 'IN', 'Uttar Pradesh', 26.7397000, 83.4497000, 'active', '2026-01-31 19:26:30', '2026-01-31 19:26:30'),
(3935, 'HDO', 'VIDX', 'Ghaziabad Hindon Airport', NULL, 'IN', 'Uttar Pradesh', 28.7050000, 77.3420000, 'active', '2026-01-31 19:26:30', '2026-01-31 19:26:30'),
(3936, 'HRH', NULL, 'Aligarh Airport', NULL, 'IN', 'Uttar Pradesh', 27.8588000, 78.1486000, 'active', '2026-01-31 19:26:30', '2026-01-31 19:26:30'),
(3937, 'IXD', 'VIAL', 'Allahabad Airport (Bamrauli Air Force Base)', NULL, 'IN', 'Uttar Pradesh', 25.4401000, 81.7339000, 'active', '2026-01-31 19:26:31', '2026-01-31 19:26:31'),
(3938, 'KNU', 'VIKA', 'Kanpur Airport (Chakeri Air Force Station)', NULL, 'IN', 'Uttar Pradesh', 26.4043000, 80.4101000, 'active', '2026-01-31 19:26:31', '2026-01-31 19:26:31'),
(3939, 'LKO', 'VILK', 'Chaudhary Charan Singh International Airport', NULL, 'IN', 'Uttar Pradesh', 26.7606000, 80.8893000, 'active', '2026-01-31 19:26:31', '2026-01-31 19:26:31'),
(3940, 'VNS', 'VEBN', 'Lal Bahadur Shastri Airport', NULL, 'IN', 'Uttar Pradesh', 25.4524000, 82.8593000, 'active', '2026-01-31 19:26:32', '2026-01-31 19:26:32'),
(3941, 'VSV', NULL, 'Shravasti Airport', NULL, 'IN', 'Uttar Pradesh', 27.5023000, 82.0265000, 'active', '2026-01-31 19:26:32', '2026-01-31 19:26:32'),
(3942, 'DED', 'VIDN', 'Jolly Grant Airport', NULL, 'IN', 'Uttarakhand', 30.1897000, 78.1803000, 'active', '2026-01-31 19:26:32', '2026-01-31 19:26:32'),
(3943, 'PGH', 'VIPT', 'Pantnagar Airport', NULL, 'IN', 'Uttarakhand', 29.0334000, 79.4737000, 'active', '2026-01-31 19:26:33', '2026-01-31 19:26:33'),
(3944, 'CCU', 'VECC', 'Netaji Subhas Chandra Bose International Airport', NULL, 'IN', 'West Bengal', 22.6547000, 88.4467000, 'active', '2026-01-31 19:26:33', '2026-01-31 19:26:33'),
(3945, 'COH', 'VECO', 'Cooch Behar Airport', NULL, 'IN', 'West Bengal', 26.3305000, 89.4672000, 'active', '2026-01-31 19:26:33', '2026-01-31 19:26:33'),
(3946, 'IXB', 'VEBD', 'Bagdogra Airport', NULL, 'IN', 'West Bengal', 26.6812000, 88.3286000, 'active', '2026-01-31 19:26:34', '2026-01-31 19:26:34'),
(3947, 'LDA', 'VEMH', 'Malda Airport', NULL, 'IN', 'West Bengal', 25.0330000, 88.1330000, 'active', '2026-01-31 19:26:34', '2026-01-31 19:26:34'),
(3948, 'RDP', 'VEDG', 'Kazi Nazrul Islam Airport', NULL, 'IN', 'West Bengal', 23.6225000, 87.2430000, 'active', '2026-01-31 19:26:34', '2026-01-31 19:26:34'),
(3949, 'RGH', 'VEBG', 'Balurghat Airport', NULL, 'IN', 'West Bengal', 25.2617000, 88.7956000, 'active', '2026-01-31 19:26:35', '2026-01-31 19:26:35'),
(3950, 'IQA', 'ORAA', 'Al Asad Airbase', NULL, 'IQ', 'Al Anbar', 33.7856000, 42.4412000, 'active', '2026-01-31 19:26:35', '2026-01-31 19:26:35'),
(3951, 'TQD', 'ORAT', 'Al-Taqaddum Air Base', NULL, 'IQ', 'Al Anbar', 33.3381000, 43.5971000, 'active', '2026-01-31 19:26:35', '2026-01-31 19:26:35'),
(3952, 'BSR', 'ORMM', 'Basra International Airport', NULL, 'IQ', 'Al Basrah', 30.5491000, 47.6621000, 'active', '2026-01-31 19:26:36', '2026-01-31 19:26:36'),
(3953, 'NJF', 'ORNI', 'Al Najaf International Airport', NULL, 'IQ', 'An Najaf', 31.9899000, 44.4043000, 'active', '2026-01-31 19:26:36', '2026-01-31 19:26:36'),
(3954, 'EBL', 'ORER', 'Erbil International Airport', NULL, 'IQ', 'Arbil', 36.2376000, 43.9632000, 'active', '2026-01-31 19:26:36', '2026-01-31 19:26:36'),
(3955, 'ISU', 'ORSU', 'Sulaimaniyah International Airport', NULL, 'IQ', 'Arbil', 35.5617000, 45.3167000, 'active', '2026-01-31 19:26:37', '2026-01-31 19:26:37'),
(3956, 'BGW', 'ORBI', 'Baghdad International Airport', NULL, 'IQ', 'Baghdad', 33.2625000, 44.2346000, 'active', '2026-01-31 19:26:37', '2026-01-31 19:26:37'),
(3957, 'BMN', 'ORBB', 'Bamarni Airport', NULL, 'IQ', 'Dahuk', 37.0988000, 43.2666000, 'active', '2026-01-31 19:26:38', '2026-01-31 19:26:38'),
(3958, 'KIK', 'ORKK', 'Kirkuk Airport', NULL, 'IQ', 'Kirkuk', 35.4695000, 44.3489000, 'active', '2026-01-31 19:26:38', '2026-01-31 19:26:38'),
(3959, 'OSM', 'ORBM', 'Mosul International Airport', NULL, 'IQ', 'Ninawa', 36.3058000, 43.1474000, 'active', '2026-01-31 19:26:38', '2026-01-31 19:26:38'),
(3960, 'RQW', NULL, 'Qayyarah Airfield West', NULL, 'IQ', 'Ninawa', 35.7672000, 43.1251000, 'active', '2026-01-31 19:26:39', '2026-01-31 19:26:39'),
(3961, 'PYK', 'OIIP', 'Payam International Airport', NULL, 'IR', 'Alborz', 35.7761000, 50.8267000, 'active', '2026-01-31 19:26:39', '2026-01-31 19:26:39'),
(3962, 'ADU', 'OITL', 'Ardabil Airport', NULL, 'IR', 'Ardabil', 38.3257000, 48.4244000, 'active', '2026-01-31 19:26:39', '2026-01-31 19:26:39'),
(3963, 'PFQ', 'OITP', 'Parsabad-Moghan Airport', NULL, 'IR', 'Ardabil', 39.6036000, 47.8815000, 'active', '2026-01-31 19:26:40', '2026-01-31 19:26:40'),
(3964, 'HGE', 'SVHG', 'Higuerote Airport', NULL, 'IR', 'Azarbayjan-e Gharbi', 10.4625000, -66.0928000, 'active', '2026-01-31 19:26:40', '2026-01-31 19:26:40'),
(3965, 'IMQ', 'OITU', 'Maku International Airport', NULL, 'IR', 'Azarbayjan-e Gharbi', 39.3300000, 44.4300000, 'active', '2026-01-31 19:26:40', '2026-01-31 19:26:40'),
(3966, 'KHY', 'OITK', 'Khoy Airport', NULL, 'IR', 'Azarbayjan-e Gharbi', 38.4275000, 44.9736000, 'active', '2026-01-31 19:26:41', '2026-01-31 19:26:41'),
(3967, 'OMH', 'OITR', 'Urmia Airport', NULL, 'IR', 'Azarbayjan-e Gharbi', 37.6681000, 45.0687000, 'active', '2026-01-31 19:26:41', '2026-01-31 19:26:41'),
(3968, 'ACP', 'OITM', 'Sahand Airport', NULL, 'IR', 'Azarbayjan-e Sharqi', 37.3480000, 46.1279000, 'active', '2026-01-31 19:26:41', '2026-01-31 19:26:41'),
(3969, 'TBZ', 'OITT', 'Tabriz International Airport', NULL, 'IR', 'Azarbayjan-e Sharqi', 38.1339000, 46.2350000, 'active', '2026-01-31 19:26:42', '2026-01-31 19:26:42'),
(3970, 'BUZ', 'OIBB', 'Bushehr Airport', NULL, 'IR', 'Bushehr', 28.9448000, 50.8346000, 'active', '2026-01-31 19:26:42', '2026-01-31 19:26:42'),
(3971, 'IAQ', 'OIBH', 'Bahregan Airport', NULL, 'IR', 'Bushehr', 29.8400000, 50.2728000, 'active', '2026-01-31 19:26:42', '2026-01-31 19:26:42'),
(3972, 'KHA', 'OITH', 'Khaneh Airport (Piranshahr Airport)', NULL, 'IR', 'Bushehr', 36.7333000, 45.1500000, 'active', '2026-01-31 19:26:43', '2026-01-31 19:26:43'),
(3973, 'KHK', 'OIBQ', 'Kharg Airport', NULL, 'IR', 'Bushehr', 29.2603000, 50.3239000, 'active', '2026-01-31 19:26:43', '2026-01-31 19:26:43'),
(3974, 'KNR', 'OIBJ', 'Jam Airport', NULL, 'IR', 'Bushehr', 27.8205000, 52.3522000, 'active', '2026-01-31 19:26:43', '2026-01-31 19:26:43'),
(3975, 'PGU', 'OIBP', 'Persian Gulf Airport', NULL, 'IR', 'Bushehr', 27.3796000, 52.7377000, 'active', '2026-01-31 19:26:44', '2026-01-31 19:26:44'),
(3976, 'CQD', 'OIFS', 'Shahrekord Airport', NULL, 'IR', 'Chahar Mahal va Bakhtiari', 32.2972000, 50.8422000, 'active', '2026-01-31 19:26:44', '2026-01-31 19:26:44'),
(3977, 'IFH', 'OIFE', 'Hesa Air Base', NULL, 'IR', 'Esfahan', 32.9289000, 51.5611000, 'active', '2026-01-31 19:26:44', '2026-01-31 19:26:44'),
(3978, 'IFN', 'OIFM', 'Isfahan International Airport (Shahid Beheshti Int\'l)', NULL, 'IR', 'Esfahan', 32.7508000, 51.8613000, 'active', '2026-01-31 19:26:45', '2026-01-31 19:26:45'),
(3979, 'FAZ', 'OISF', 'Fasa Airport', NULL, 'IR', 'Fars', 28.8918000, 53.7233000, 'active', '2026-01-31 19:26:45', '2026-01-31 19:26:45'),
(3980, 'JAR', 'OISJ', 'Jahrom Airport', NULL, 'IR', 'Fars', 28.5867000, 53.5791000, 'active', '2026-01-31 19:26:45', '2026-01-31 19:26:45'),
(3981, 'LFM', 'OISR', 'Lamerd Airport', NULL, 'IR', 'Fars', 27.3727000, 53.1888000, 'active', '2026-01-31 19:26:46', '2026-01-31 19:26:46'),
(3982, 'LRR', 'OISL', 'Larestan International Airport', NULL, 'IR', 'Fars', 27.6747000, 54.3833000, 'active', '2026-01-31 19:26:46', '2026-01-31 19:26:46'),
(3983, 'SYZ', 'OISS', 'Shiraz International Airport (Shahid Dastghaib Int\'l)', NULL, 'IR', 'Fars', 29.5392000, 52.5898000, 'active', '2026-01-31 19:26:46', '2026-01-31 19:26:46'),
(3984, 'RAS', 'OIGG', 'Rasht Airport', NULL, 'IR', 'Gilan', 37.3233000, 49.6178000, 'active', '2026-01-31 19:26:47', '2026-01-31 19:26:47'),
(3985, 'GBT', 'OING', 'Gorgan Airport', NULL, 'IR', 'Golestan', 36.9094000, 54.4013000, 'active', '2026-01-31 19:26:47', '2026-01-31 19:26:47'),
(3986, 'KLM', 'OINE', 'Kalaleh Airport', NULL, 'IR', 'Golestan', 37.3833000, 55.4520000, 'active', '2026-01-31 19:26:47', '2026-01-31 19:26:47'),
(3987, 'HDM', 'OIHH', 'Hamadan Airport', NULL, 'IR', 'Hamadan', 34.8692000, 48.5525000, 'active', '2026-01-31 19:26:48', '2026-01-31 19:26:48'),
(3988, 'NUJ', 'OIHS', 'Hamedan Air Base (Nogeh Airport)', NULL, 'IR', 'Hamadan', 35.2117000, 48.6533000, 'active', '2026-01-31 19:26:48', '2026-01-31 19:26:48'),
(3989, 'AEU', 'OIBA', 'Abu Musa Airport', NULL, 'IR', 'Hormozgan', 25.8757000, 55.0330000, 'active', '2026-01-31 19:26:48', '2026-01-31 19:26:48'),
(3990, 'BDH', 'OIBL', 'Bandar Lengeh Airport', NULL, 'IR', 'Hormozgan', 26.5320000, 54.8248000, 'active', '2026-01-31 19:26:49', '2026-01-31 19:26:49'),
(3991, 'BND', 'OIKB', 'Bandar Abbas International Airport', NULL, 'IR', 'Hormozgan', 27.2183000, 56.3778000, 'active', '2026-01-31 19:26:49', '2026-01-31 19:26:49'),
(3992, 'GSM', 'OIKQ', 'Dayrestan Airport (Qeshm International Airport)', NULL, 'IR', 'Hormozgan', 26.7546000, 55.9024000, 'active', '2026-01-31 19:26:49', '2026-01-31 19:26:49'),
(3993, 'HDR', 'OIKP', 'Havadarya Airport', NULL, 'IR', 'Hormozgan', 27.1583000, 56.1725000, 'active', '2026-01-31 19:26:50', '2026-01-31 19:26:50'),
(3994, 'JSK', 'OIZJ', 'Jask Airport', NULL, 'IR', 'Hormozgan', 25.6523000, 57.7878000, 'active', '2026-01-31 19:26:50', '2026-01-31 19:26:50'),
(3995, 'KIH', 'OIBK', 'Kish International Airport', NULL, 'IR', 'Hormozgan', 26.5262000, 53.9802000, 'active', '2026-01-31 19:26:50', '2026-01-31 19:26:50'),
(3996, 'LVP', 'OIBV', 'Lavan Airport', NULL, 'IR', 'Hormozgan', 26.8103000, 53.3563000, 'active', '2026-01-31 19:26:51', '2026-01-31 19:26:51'),
(3997, 'SXI', 'OIBS', 'Sirri Island Airport', NULL, 'IR', 'Hormozgan', 25.9089000, 54.5394000, 'active', '2026-01-31 19:26:51', '2026-01-31 19:26:51'),
(3998, 'IIL', 'OICI', 'Ilam Airport', NULL, 'IR', 'Ilam', 33.5866000, 46.4048000, 'active', '2026-01-31 19:26:51', '2026-01-31 19:26:51'),
(3999, 'BXR', 'OIKM', 'Bam Airport', NULL, 'IR', 'Kerman', 29.0842000, 58.4500000, 'active', '2026-01-31 19:26:52', '2026-01-31 19:26:52'),
(4000, 'JYR', 'OIKJ', 'Jiroft Airport', NULL, 'IR', 'Kerman', 28.7269000, 57.6703000, 'active', '2026-01-31 19:26:52', '2026-01-31 19:26:52'),
(4001, 'KER', 'OIKK', 'Kerman Airport', NULL, 'IR', 'Kerman', 30.2744000, 56.9511000, 'active', '2026-01-31 19:26:52', '2026-01-31 19:26:52'),
(4002, 'RJN', 'OIKR', 'Rafsanjan Airport', NULL, 'IR', 'Kerman', 30.2977000, 56.0511000, 'active', '2026-01-31 19:26:53', '2026-01-31 19:26:53'),
(4003, 'SYJ', 'OIKY', 'Sirjan Airport', NULL, 'IR', 'Kerman', 29.5509000, 55.6727000, 'active', '2026-01-31 19:26:53', '2026-01-31 19:26:53'),
(4004, 'KSH', 'OICC', 'Shahid Ashrafi Esfahani Airport (Kermanshah Airport)', NULL, 'IR', 'Kermanshah', 34.3459000, 47.1581000, 'active', '2026-01-31 19:26:53', '2026-01-31 19:26:53'),
(4005, 'TCX', 'OIMT', 'Tabas Airport', NULL, 'IR', 'Khorasan-e Jonubi', 33.6678000, 56.8927000, 'active', '2026-01-31 19:26:54', '2026-01-31 19:26:54'),
(4006, 'XBJ', 'OIMB', 'Birjand International Airport', NULL, 'IR', 'Khorasan-e Jonubi', 32.8981000, 59.2661000, 'active', '2026-01-31 19:26:54', '2026-01-31 19:26:54'),
(4007, 'AFZ', 'OIMS', 'Sabzevar Airport', NULL, 'IR', 'Khorasan-e Razavi', 36.1681000, 57.5952000, 'active', '2026-01-31 19:26:54', '2026-01-31 19:26:54'),
(4008, 'CKT', 'OIMC', 'Sarakhs Airport', NULL, 'IR', 'Khorasan-e Razavi', 36.5012000, 61.0649000, 'active', '2026-01-31 19:26:55', '2026-01-31 19:26:55'),
(4009, 'MHD', 'OIMM', 'Mashhad International Airport (Shahid Hashemi Nejad Airport)', NULL, 'IR', 'Khorasan-e Razavi', 36.2352000, 59.6410000, 'active', '2026-01-31 19:26:55', '2026-01-31 19:26:55'),
(4010, 'BJB', 'OIMN', 'Bojnord Airport', NULL, 'IR', 'Khorasan-e Shomali', 37.4930000, 57.3082000, 'active', '2026-01-31 19:26:55', '2026-01-31 19:26:55'),
(4011, 'ABD', 'OIAA', 'Abadan International Airport', NULL, 'IR', 'Khuzestan', 30.3711000, 48.2283000, 'active', '2026-01-31 19:26:56', '2026-01-31 19:26:56'),
(4012, 'AKW', 'OIAG', 'Aghajari Airport', NULL, 'IR', 'Khuzestan', 30.7444000, 49.6772000, 'active', '2026-01-31 19:26:56', '2026-01-31 19:26:56'),
(4013, 'AWZ', 'OIAW', 'Ahvaz International Airport', NULL, 'IR', 'Khuzestan', 31.3374000, 48.7620000, 'active', '2026-01-31 19:26:56', '2026-01-31 19:26:56'),
(4014, 'DEF', 'OIAD', 'Dezful Airport', NULL, 'IR', 'Khuzestan', 32.4344000, 48.3976000, 'active', '2026-01-31 19:26:57', '2026-01-31 19:26:57'),
(4015, 'MRX', 'OIAM', 'Mahshahr Airport', NULL, 'IR', 'Khuzestan', 30.5562000, 49.1519000, 'active', '2026-01-31 19:26:57', '2026-01-31 19:26:57'),
(4016, 'OMI', 'OIAJ', 'Omidiyeh Air Base', NULL, 'IR', 'Khuzestan', 30.8352000, 49.5349000, 'active', '2026-01-31 19:26:57', '2026-01-31 19:26:57'),
(4017, 'GCH', 'OIAH', 'Gachsaran Airport', NULL, 'IR', 'Kohgiluyeh va Bowyer Ahmad', 30.3376000, 50.8280000, 'active', '2026-01-31 19:26:58', '2026-01-31 19:26:58'),
(4018, 'YES', 'OISY', 'Yasuj Airport', NULL, 'IR', 'Kohgiluyeh va Bowyer Ahmad', 30.7005000, 51.5451000, 'active', '2026-01-31 19:26:58', '2026-01-31 19:26:58'),
(4019, 'SDG', 'OICS', 'Sanandaj Airport', NULL, 'IR', 'Kordestan', 35.2459000, 47.0092000, 'active', '2026-01-31 19:26:58', '2026-01-31 19:26:58'),
(4020, 'KHD', 'OICK', 'Khorramabad Airport', NULL, 'IR', 'Lorestan', 33.4354000, 48.2829000, 'active', '2026-01-31 19:26:59', '2026-01-31 19:26:59'),
(4021, 'AJK', 'OIHR', 'Arak Airport', NULL, 'IR', 'Markazi', 34.1381000, 49.8473000, 'active', '2026-01-31 19:26:59', '2026-01-31 19:26:59'),
(4022, 'BSM', 'OINJ', 'Bishe Kola Air Base', NULL, 'IR', 'Mazandaran', 36.6551000, 52.3496000, 'active', '2026-01-31 19:26:59', '2026-01-31 19:26:59'),
(4023, 'NSH', 'OINN', 'Noshahr Airport', NULL, 'IR', 'Mazandaran', 36.6633000, 51.4647000, 'active', '2026-01-31 19:27:00', '2026-01-31 19:27:00'),
(4024, 'RZR', 'OINR', 'Ramsar International Airport', NULL, 'IR', 'Mazandaran', 36.9099000, 50.6796000, 'active', '2026-01-31 19:27:00', '2026-01-31 19:27:00'),
(4025, 'SRY', 'OINZ', 'Dasht-e Naz Airport', NULL, 'IR', 'Mazandaran', 36.6358000, 53.1936000, 'active', '2026-01-31 19:27:00', '2026-01-31 19:27:00'),
(4026, 'GZW', 'OIIK', 'Qazvin Airport', NULL, 'IR', 'Qazvin', 36.2401000, 50.0471000, 'active', '2026-01-31 19:27:01', '2026-01-31 19:27:01'),
(4027, 'RUD', 'OIMJ', 'Shahroud Airport', NULL, 'IR', 'Semnan', 36.4253000, 55.1042000, 'active', '2026-01-31 19:27:01', '2026-01-31 19:27:01'),
(4028, 'SNX', 'OIIS', 'Semnan Municipal Airport', NULL, 'IR', 'Semnan', 35.5911000, 53.4951000, 'active', '2026-01-31 19:27:01', '2026-01-31 19:27:01'),
(4029, 'ACZ', 'OIZB', 'Zabol Airport', NULL, 'IR', 'Sistan va Baluchestan', 31.0983000, 61.5439000, 'active', '2026-01-31 19:27:02', '2026-01-31 19:27:02'),
(4030, 'AMB', 'FMNE', 'Ambilobe Airport', NULL, 'IR', 'Sistan va Baluchestan', -13.1884000, 48.9880000, 'active', '2026-01-31 19:27:02', '2026-01-31 19:27:02'),
(4031, 'ANM', 'FMNH', 'Antsirabato Airport', NULL, 'IR', 'Sistan va Baluchestan', -14.9994000, 50.3202000, 'active', '2026-01-31 19:27:03', '2026-01-31 19:27:03'),
(4032, 'DIE', 'FMNA', 'Arrachart Airport', NULL, 'IR', 'Sistan va Baluchestan', -12.3494000, 49.2917000, 'active', '2026-01-31 19:27:03', '2026-01-31 19:27:03'),
(4033, 'DOA', NULL, 'Doany Airport', NULL, 'IR', 'Sistan va Baluchestan', -14.3681000, 49.5108000, 'active', '2026-01-31 19:27:03', '2026-01-31 19:27:03'),
(4034, 'IHR', 'OIZI', 'Iranshahr Airport', NULL, 'IR', 'Sistan va Baluchestan', 27.2361000, 60.7200000, 'active', '2026-01-31 19:27:04', '2026-01-31 19:27:04'),
(4035, 'IVA', 'FMNJ', 'Ambanja Airport', NULL, 'IR', 'Sistan va Baluchestan', -13.4848000, 48.6327000, 'active', '2026-01-31 19:27:04', '2026-01-31 19:27:04'),
(4036, 'NOS', 'FMNN', 'Fascene Airport', NULL, 'IR', 'Sistan va Baluchestan', -13.3121000, 48.3148000, 'active', '2026-01-31 19:27:04', '2026-01-31 19:27:04'),
(4037, 'SVB', 'FMNS', 'Sambava Airport', NULL, 'IR', 'Sistan va Baluchestan', -14.2786000, 50.1747000, 'active', '2026-01-31 19:27:05', '2026-01-31 19:27:05'),
(4038, 'VOH', 'FMNV', 'Vohemar Airport', NULL, 'IR', 'Sistan va Baluchestan', -13.3758000, 50.0028000, 'active', '2026-01-31 19:27:05', '2026-01-31 19:27:05'),
(4039, 'ZAH', 'OIZH', 'Zahedan Airport', NULL, 'IR', 'Sistan va Baluchestan', 29.4757000, 60.9062000, 'active', '2026-01-31 19:27:05', '2026-01-31 19:27:05'),
(4040, 'ZBR', 'OIZC', 'Konarak Airport', NULL, 'IR', 'Sistan va Baluchestan', 25.4433000, 60.3821000, 'active', '2026-01-31 19:27:06', '2026-01-31 19:27:06'),
(4041, 'ZWA', 'FMND', 'Andapa Airport', NULL, 'IR', 'Sistan va Baluchestan', -14.6517000, 49.6206000, 'active', '2026-01-31 19:27:06', '2026-01-31 19:27:06'),
(4042, 'IKA', 'OIIE', 'Imam Khomeini International Airport', NULL, 'IR', 'Tehran', 35.4161000, 51.1522000, 'active', '2026-01-31 19:27:06', '2026-01-31 19:27:06'),
(4043, 'KKS', 'OIFK', 'Kashan Airport', NULL, 'IR', 'Tehran', 33.8953000, 51.5770000, 'active', '2026-01-31 19:27:07', '2026-01-31 19:27:07'),
(4044, 'THR', 'OIII', 'Mehrabad International Airport', NULL, 'IR', 'Tehran', 35.6892000, 51.3134000, 'active', '2026-01-31 19:27:07', '2026-01-31 19:27:07'),
(4045, 'AZD', 'OIYY', 'Shahid Sadooghi Airport', NULL, 'IR', 'Yazd', 31.9049000, 54.2765000, 'active', '2026-01-31 19:27:07', '2026-01-31 19:27:07'),
(4046, 'JWN', 'OITZ', 'Zanjan Airport', NULL, 'IR', 'Zanjan', 36.7737000, 48.3594000, 'active', '2026-01-31 19:27:08', '2026-01-31 19:27:08'),
(4047, 'BGJ', 'BIBF', 'Borgarfjorour Eystri Airport', NULL, 'IS', 'Austurland', 65.5164000, -13.8050000, 'active', '2026-01-31 19:27:08', '2026-01-31 19:27:08'),
(4048, 'DJU', 'BIDV', 'Djupivogur Airport', NULL, 'IS', 'Austurland', 64.6442000, -14.2828000, 'active', '2026-01-31 19:27:08', '2026-01-31 19:27:08'),
(4049, 'HFN', 'BIHN', 'Hornafjorour Airport', NULL, 'IS', 'Austurland', 64.2956000, -15.2272000, 'active', '2026-01-31 19:27:09', '2026-01-31 19:27:09'),
(4050, 'RKV', 'BIRK', 'Reykjavík Airport', NULL, 'IS', 'Hofudborgarsvaedi', 64.1300000, -21.9406000, 'active', '2026-01-31 19:27:09', '2026-01-31 19:27:09'),
(4051, 'AEY', 'BIAR', 'Akureyri Airport', NULL, 'IS', 'Nordurland eystra', 65.6600000, -18.0727000, 'active', '2026-01-31 19:27:09', '2026-01-31 19:27:09'),
(4052, 'BJD', 'BIBK', 'Bakkafjorour Airport', NULL, 'IS', 'Nordurland eystra', 66.0219000, -14.8244000, 'active', '2026-01-31 19:27:10', '2026-01-31 19:27:10'),
(4053, 'BXV', 'BIBV', 'Breiodalsvik Airport', NULL, 'IS', 'Nordurland eystra', 64.7900000, -14.0228000, 'active', '2026-01-31 19:27:10', '2026-01-31 19:27:10'),
(4054, 'EGS', 'BIEG', 'Egilsstaoir Airport', NULL, 'IS', 'Nordurland eystra', 65.2833000, -14.4014000, 'active', '2026-01-31 19:27:10', '2026-01-31 19:27:10'),
(4055, 'FAS', 'BIFF', 'Faskruosfjorour Airport', NULL, 'IS', 'Nordurland eystra', 64.9317000, -14.0606000, 'active', '2026-01-31 19:27:11', '2026-01-31 19:27:11'),
(4056, 'GRY', 'BIGR', 'Grimsey Airport', NULL, 'IS', 'Nordurland eystra', 66.5458000, -18.0173000, 'active', '2026-01-31 19:27:11', '2026-01-31 19:27:11'),
(4057, 'HZK', 'BIHU', 'Husavik Airport', NULL, 'IS', 'Nordurland eystra', 65.9523000, -17.4260000, 'active', '2026-01-31 19:27:11', '2026-01-31 19:27:11'),
(4058, 'MVA', 'BIRL', 'Myvatn Airport', NULL, 'IS', 'Nordurland eystra', 65.6558000, -16.9181000, 'active', '2026-01-31 19:27:12', '2026-01-31 19:27:12'),
(4059, 'NOR', 'BINF', 'Norofjorour Airport', NULL, 'IS', 'Nordurland eystra', 65.1319000, -13.7464000, 'active', '2026-01-31 19:27:12', '2026-01-31 19:27:12'),
(4060, 'OFJ', 'BIOF', 'Olafsfjorour Airport', NULL, 'IS', 'Nordurland eystra', 66.0833000, -18.6667000, 'active', '2026-01-31 19:27:12', '2026-01-31 19:27:12'),
(4061, 'OPA', 'BIKP', 'Kopasker Airport', NULL, 'IS', 'Nordurland eystra', 66.3108000, -16.4667000, 'active', '2026-01-31 19:27:13', '2026-01-31 19:27:13'),
(4062, 'RFN', 'BIRG', 'Raufarhofn Airport', NULL, 'IS', 'Nordurland eystra', 66.4064000, -15.9183000, 'active', '2026-01-31 19:27:13', '2026-01-31 19:27:13'),
(4063, 'SIJ', 'BISI', 'Siglufjorour Airport', NULL, 'IS', 'Nordurland eystra', 66.1333000, -18.9167000, 'active', '2026-01-31 19:27:14', '2026-01-31 19:27:14'),
(4064, 'THO', 'BITN', 'Thorshofn Airport', NULL, 'IS', 'Nordurland eystra', 66.2185000, -15.3356000, 'active', '2026-01-31 19:27:14', '2026-01-31 19:27:14'),
(4065, 'VPN', 'BIVO', 'Vopnafjorour Airport', NULL, 'IS', 'Nordurland eystra', 65.7206000, -14.8506000, 'active', '2026-01-31 19:27:14', '2026-01-31 19:27:14'),
(4066, 'BIU', 'BIBD', 'Bildudalur Airport', NULL, 'IS', 'Nordurland vestra', 65.6413000, -23.5462000, 'active', '2026-01-31 19:27:15', '2026-01-31 19:27:15'),
(4067, 'BLO', 'BIBL', 'Blonduos Airport', NULL, 'IS', 'Nordurland vestra', 65.6450000, -20.2875000, 'active', '2026-01-31 19:27:15', '2026-01-31 19:27:15'),
(4068, 'OLI', 'BIRF', 'Rif Airport', NULL, 'IS', 'Nordurland vestra', 64.9114000, -23.8231000, 'active', '2026-01-31 19:27:15', '2026-01-31 19:27:15'),
(4069, 'PFJ', 'BIPA', 'Patreksfjorour Airport', NULL, 'IS', 'Nordurland vestra', 65.5558000, -23.9650000, 'active', '2026-01-31 19:27:16', '2026-01-31 19:27:16'),
(4070, 'SAK', 'BIKR', 'Sauoarkrokur Airport', NULL, 'IS', 'Nordurland vestra', 65.7317000, -19.5728000, 'active', '2026-01-31 19:27:16', '2026-01-31 19:27:16'),
(4071, 'FAG', 'BIFM', 'Fagurholsmyri Airport', NULL, 'IS', 'Sudurland', 63.8747000, -16.6411000, 'active', '2026-01-31 19:27:17', '2026-01-31 19:27:17'),
(4072, 'VEY', 'BIVM', 'Vestmannaeyjar Airport', NULL, 'IS', 'Sudurland', 63.4243000, -20.2789000, 'active', '2026-01-31 19:27:17', '2026-01-31 19:27:17'),
(4073, 'KEF', 'BIKF', 'Keflavík International Airport', NULL, 'IS', 'Sudurnes', 63.9850000, -22.6056000, 'active', '2026-01-31 19:27:17', '2026-01-31 19:27:17'),
(4074, 'FLI', NULL, 'Holt Airport', NULL, 'IS', 'Vestfirdir', 66.0142000, -23.4417000, 'active', '2026-01-31 19:27:18', '2026-01-31 19:27:18'),
(4075, 'GJR', 'BIGJ', 'Gjogur Airport', NULL, 'IS', 'Vestfirdir', 65.9953000, -21.3269000, 'active', '2026-01-31 19:27:18', '2026-01-31 19:27:18'),
(4076, 'HVK', 'BIHK', 'Holmavik Airport', NULL, 'IS', 'Vestfirdir', 65.7047000, -21.6964000, 'active', '2026-01-31 19:27:18', '2026-01-31 19:27:18'),
(4077, 'IFJ', 'BIIS', 'Isafjorour Airport', NULL, 'IS', 'Vestfirdir', 66.0581000, -23.1353000, 'active', '2026-01-31 19:27:19', '2026-01-31 19:27:19'),
(4078, 'RHA', 'BIRE', 'Reykholar Airport', NULL, 'IS', 'Vestfirdir', 65.4526000, -22.2061000, 'active', '2026-01-31 19:27:19', '2026-01-31 19:27:19'),
(4079, 'TEY', 'BITE', 'Thingeyri Airport', NULL, 'IS', 'Vestfirdir', 65.8703000, -23.5600000, 'active', '2026-01-31 19:27:19', '2026-01-31 19:27:19'),
(4080, 'GUU', 'BIGF', 'Grundarfjorour Airport', NULL, 'IS', 'Vesturland', 64.9914000, -23.2247000, 'active', '2026-01-31 19:27:20', '2026-01-31 19:27:20'),
(4081, 'SYK', 'BIST', 'Stykkisholmur Airport', NULL, 'IS', 'Vesturland', 65.0581000, -22.7942000, 'active', '2026-01-31 19:27:20', '2026-01-31 19:27:20'),
(4082, 'PSR', 'LIBP', 'Abruzzo Airport', NULL, 'IT', 'Abruzzo', 42.4317000, 14.1811000, 'active', '2026-01-31 19:27:20', '2026-01-31 19:27:20'),
(4083, 'QAQ', 'LIAP', 'L\'Aquila-Preturo Airport', NULL, 'IT', 'Abruzzo', 42.3799000, 13.3092000, 'active', '2026-01-31 19:27:21', '2026-01-31 19:27:21'),
(4084, 'CRV', 'LIBC', 'Crotone Airport (Sant\'Anna Airport)', NULL, 'IT', 'Calabria', 38.9972000, 17.0802000, 'active', '2026-01-31 19:27:21', '2026-01-31 19:27:21'),
(4085, 'REG', 'LICR', 'Reggio di Calabria Airport', NULL, 'IT', 'Calabria', 38.0712000, 15.6516000, 'active', '2026-01-31 19:27:21', '2026-01-31 19:27:21'),
(4086, 'SUF', 'LICA', 'Lamezia Terme International Airport', NULL, 'IT', 'Calabria', 38.9054000, 16.2423000, 'active', '2026-01-31 19:27:22', '2026-01-31 19:27:22'),
(4087, 'NAP', 'LIRN', 'Naples International Airport', NULL, 'IT', 'Campania', 40.8860000, 14.2908000, 'active', '2026-01-31 19:27:22', '2026-01-31 19:27:22'),
(4088, 'QSR', 'LIRI', 'Salerno Costa d\'Amalfi Airport (Pontecagnano Airport)', NULL, 'IT', 'Campania', 40.6204000, 14.9113000, 'active', '2026-01-31 19:27:23', '2026-01-31 19:27:23'),
(4089, 'BLQ', 'LIPE', 'Bologna Guglielmo Marconi Airport', NULL, 'IT', 'Emilia-Romagna', 44.5354000, 11.2887000, 'active', '2026-01-31 19:27:23', '2026-01-31 19:27:23'),
(4090, 'FRL', 'LIPK', 'Forli International Airport (Luigi Ridolfi Airport)', NULL, 'IT', 'Emilia-Romagna', 44.1948000, 12.0701000, 'active', '2026-01-31 19:27:23', '2026-01-31 19:27:23'),
(4091, 'PMF', 'LIMP', 'Giuseppe Verdi Parma International Airport', NULL, 'IT', 'Emilia-Romagna', 44.8212200, 10.2974000, 'active', '2026-01-31 19:27:24', '2026-01-31 19:27:24'),
(4092, 'RAN', 'LIDR', 'Ravenna Airport', NULL, 'IT', 'Emilia-Romagna', 44.3639000, 12.2250000, 'active', '2026-01-31 19:27:24', '2026-01-31 19:27:24'),
(4093, 'RMI', 'LIPR', 'Federico Fellini International Airport', NULL, 'IT', 'Emilia-Romagna', 44.0203000, 12.6117000, 'active', '2026-01-31 19:27:24', '2026-01-31 19:27:24'),
(4094, 'AVB', 'LIPA', 'Aviano Air Base', NULL, 'IT', 'Friuli-Venezia Giulia', 46.0319000, 12.5965000, 'active', '2026-01-31 19:27:25', '2026-01-31 19:27:25'),
(4095, 'TRS', 'LIPQ', 'Trieste - Friuli Venezia Giulia Airport', NULL, 'IT', 'Friuli-Venezia Giulia', 45.8275000, 13.4722000, 'active', '2026-01-31 19:27:25', '2026-01-31 19:27:25'),
(4096, 'UDN', 'LIPD', 'Campoformido Airport', NULL, 'IT', 'Friuli-Venezia Giulia', 46.0322000, 13.1868000, 'active', '2026-01-31 19:27:25', '2026-01-31 19:27:25'),
(4097, 'CIA', 'LIRA', 'Rome-Ciampino International Airport', NULL, 'IT', 'Lazio', 41.7991000, 12.5929000, 'active', '2026-01-31 19:27:26', '2026-01-31 19:27:26'),
(4098, 'FCO', 'LIRF', 'Rome–Fiumicino International Airport', NULL, 'IT', 'Lazio', 41.8003000, 12.2389000, 'active', '2026-01-31 19:27:26', '2026-01-31 19:27:26'),
(4099, 'ALL', 'LIMG', 'Albenga Airport', NULL, 'IT', 'Liguria', 44.0506000, 8.1274300, 'active', '2026-01-31 19:27:26', '2026-01-31 19:27:26'),
(4100, 'GOA', 'LIMJ', 'Genoa Cristoforo Colombo Airport', NULL, 'IT', 'Liguria', 44.4133000, 8.8375000, 'active', '2026-01-31 19:27:27', '2026-01-31 19:27:27'),
(4101, 'BGY', 'LIME', 'Milan Bergamo Airport', NULL, 'IT', 'Lombardia', 45.6654600, 9.6994800, 'active', '2026-01-31 19:27:27', '2026-01-31 19:27:27'),
(4102, 'LIN', 'LIML', 'Milan-Linate Airport', NULL, 'IT', 'Lombardia', 45.4494000, 9.2783000, 'active', '2026-01-31 19:27:27', '2026-01-31 19:27:27'),
(4103, 'MXP', 'LIMC', 'Milan-Malpensa Airport', NULL, 'IT', 'Lombardia', 45.6306000, 8.7281100, 'active', '2026-01-31 19:27:28', '2026-01-31 19:27:28'),
(4104, 'VBS', 'LIPO', 'Brescia Airport (Gabriele D\'Annunzio Airport)', NULL, 'IT', 'Lombardia', 45.4289000, 10.3306000, 'active', '2026-01-31 19:27:28', '2026-01-31 19:27:28'),
(4105, 'AOI', 'LIPY', 'Ancona Falconara Airport', NULL, 'IT', 'Marche', 43.6163000, 13.3623000, 'active', '2026-01-31 19:27:28', '2026-01-31 19:27:28'),
(4106, 'CUF', 'LIMZ', 'Cuneo International Airport', NULL, 'IT', 'Piemonte', 44.5470000, 7.6232200, 'active', '2026-01-31 19:27:29', '2026-01-31 19:27:29'),
(4107, 'TRN', 'LIMF', 'Turin Airport (Caselle Airport)', NULL, 'IT', 'Piemonte', 45.2008000, 7.6496300, 'active', '2026-01-31 19:27:29', '2026-01-31 19:27:29'),
(4108, 'BDS', 'LIBR', 'Brindisi - Salento Airport', NULL, 'IT', 'Puglia', 40.6576000, 17.9470000, 'active', '2026-01-31 19:27:29', '2026-01-31 19:27:29'),
(4109, 'BRI', 'LIBD', 'Bari Karol Wojtyla Airport', NULL, 'IT', 'Puglia', 41.1389000, 16.7606000, 'active', '2026-01-31 19:27:30', '2026-01-31 19:27:30'),
(4110, 'FOG', 'LIBF', 'Foggia Gino Lisa Airport', NULL, 'IT', 'Puglia', 41.4329000, 15.5350000, 'active', '2026-01-31 19:27:30', '2026-01-31 19:27:30'),
(4111, 'LCC', 'LIBN', 'Galatina Air Base', NULL, 'IT', 'Puglia', 40.2392000, 18.1333000, 'active', '2026-01-31 19:27:30', '2026-01-31 19:27:30'),
(4112, 'TAR', 'LIBG', 'Taranto-Grottaglie Airport', NULL, 'IT', 'Puglia', 40.5175000, 17.4032000, 'active', '2026-01-31 19:27:31', '2026-01-31 19:27:31'),
(4113, 'TQR', NULL, 'San Domino Island Heliport', NULL, 'IT', 'Puglia', 42.1175000, 15.4907000, 'active', '2026-01-31 19:27:31', '2026-01-31 19:27:31'),
(4114, 'AHO', 'LIEA', 'Alghero-Fertilia Airport', NULL, 'IT', 'Sardegna', 40.6321000, 8.2907700, 'active', '2026-01-31 19:27:32', '2026-01-31 19:27:32'),
(4115, 'CAG', 'LIEE', 'Cagliari Elmas Airport', NULL, 'IT', 'Sardegna', 39.2515000, 9.0542800, 'active', '2026-01-31 19:27:32', '2026-01-31 19:27:32'),
(4116, 'DCI', 'LIED', 'Decimomannu Air Base', NULL, 'IT', 'Sardegna', 39.3542000, 8.9724800, 'active', '2026-01-31 19:27:32', '2026-01-31 19:27:32'),
(4117, 'FNU', 'LIER', 'Oristano-Fenosu Airport', NULL, 'IT', 'Sardegna', 39.8953000, 8.6426600, 'active', '2026-01-31 19:27:33', '2026-01-31 19:27:33'),
(4118, 'OLB', 'LIEO', 'Olbia Costa Smeralda Airport', NULL, 'IT', 'Sardegna', 40.8987000, 9.5176300, 'active', '2026-01-31 19:27:33', '2026-01-31 19:27:33'),
(4119, 'TTB', 'LIET', 'Tortoli Airport (Arbatax Airport)', NULL, 'IT', 'Sardegna', 39.9188000, 9.6829800, 'active', '2026-01-31 19:27:33', '2026-01-31 19:27:33'),
(4120, 'CIY', 'LICB', 'Comiso Airport', NULL, 'IT', 'Sicilia', 36.9946000, 14.6072000, 'active', '2026-01-31 19:27:34', '2026-01-31 19:27:34'),
(4121, 'CTA', 'LICC', 'Catania-Fontanarossa Airport', NULL, 'IT', 'Sicilia', 37.4668000, 15.0664000, 'active', '2026-01-31 19:27:34', '2026-01-31 19:27:34'),
(4122, 'LMP', 'LICD', 'Lampedusa Airport', NULL, 'IT', 'Sicilia', 35.4979000, 12.6181000, 'active', '2026-01-31 19:27:34', '2026-01-31 19:27:34'),
(4123, 'NSY', 'LICZ', 'Naval Air Station Sigonella', NULL, 'IT', 'Sicilia', 37.4017000, 14.9224000, 'active', '2026-01-31 19:27:35', '2026-01-31 19:27:35'),
(4124, 'PMO', 'LICJ', 'Falcone-Borsellino Airport (Punta Raisi Airport)', NULL, 'IT', 'Sicilia', 38.1760000, 13.0910000, 'active', '2026-01-31 19:27:35', '2026-01-31 19:27:35'),
(4125, 'PNL', 'LICG', 'Pantelleria Airport', NULL, 'IT', 'Sicilia', 36.8165000, 11.9689000, 'active', '2026-01-31 19:27:35', '2026-01-31 19:27:35'),
(4126, 'TPS', 'LICT', 'Vincenzo Florio Airport', NULL, 'IT', 'Sicilia', 37.9114000, 12.4880000, 'active', '2026-01-31 19:27:36', '2026-01-31 19:27:36'),
(4127, 'EBA', 'LIRJ', 'Marina di Campo Airport', NULL, 'IT', 'Toscana', 42.7603000, 10.2394000, 'active', '2026-01-31 19:27:36', '2026-01-31 19:27:36'),
(4128, 'FLR', 'LIRQ', 'Florence Airport', NULL, 'IT', 'Toscana', 43.8100000, 11.2051000, 'active', '2026-01-31 19:27:36', '2026-01-31 19:27:36'),
(4129, 'GRS', 'LIRS', 'Grosseto Airport', NULL, 'IT', 'Toscana', 42.7597000, 11.0719000, 'active', '2026-01-31 19:27:38', '2026-01-31 19:27:38'),
(4130, 'LCV', 'LIQL', 'Lucca-Tassignano Airport', NULL, 'IT', 'Toscana', 43.8258000, 10.5779000, 'active', '2026-01-31 19:27:38', '2026-01-31 19:27:38'),
(4131, 'PSA', 'LIRP', 'Pisa International Airport (Galileo Galilei Airport)', NULL, 'IT', 'Toscana', 43.6839000, 10.3927000, 'active', '2026-01-31 19:27:39', '2026-01-31 19:27:39'),
(4132, 'SAY', 'LIQS', 'Siena-Ampugnano Airport', NULL, 'IT', 'Toscana', 43.2563000, 11.2550000, 'active', '2026-01-31 19:27:39', '2026-01-31 19:27:39'),
(4133, 'BZO', 'LIPB', 'Bolzano Airport', NULL, 'IT', 'Trentino-Alto Adige', 46.4602000, 11.3264000, 'active', '2026-01-31 19:27:39', '2026-01-31 19:27:39'),
(4134, 'PEG', 'LIRZ', 'Perugia San Francesco d\'Assisi - Umbria International Airport', NULL, 'IT', 'Umbria', 43.0959000, 12.5132000, 'active', '2026-01-31 19:27:40', '2026-01-31 19:27:40'),
(4135, 'AOT', 'LIMW', 'Aosta Valley Airport', NULL, 'IT', 'Valle d\'Aosta', 45.7385000, 7.3687200, 'active', '2026-01-31 19:27:40', '2026-01-31 19:27:40'),
(4136, 'BLX', 'LIDB', 'Belluno Airport', NULL, 'IT', 'Veneto', 46.1665000, 12.2504000, 'active', '2026-01-31 19:27:40', '2026-01-31 19:27:40'),
(4137, 'TSF', 'LIPH', 'Treviso-Sant\'Angelo Airport', NULL, 'IT', 'Veneto', 45.6484000, 12.1944000, 'active', '2026-01-31 19:27:41', '2026-01-31 19:27:41'),
(4138, 'VCE', 'LIPZ', 'Venice Marco Polo Airport', NULL, 'IT', 'Veneto', 45.5053000, 12.3519000, 'active', '2026-01-31 19:27:41', '2026-01-31 19:27:41'),
(4139, 'VIC', 'LIPT', 'Vicenza Airport', NULL, 'IT', 'Veneto', 45.5734000, 11.5295000, 'active', '2026-01-31 19:27:41', '2026-01-31 19:27:41'),
(4140, 'VRN', 'LIPX', 'Verona Villafranca Airport', NULL, 'IT', 'Veneto', 45.3957000, 10.8885000, 'active', '2026-01-31 19:27:42', '2026-01-31 19:27:42'),
(4141, 'JER', 'EGJJ', 'Jersey Airport', NULL, 'JE', 'Jersey', 49.2081000, -2.1952800, 'active', '2026-01-31 19:27:42', '2026-01-31 19:27:42'),
(4142, 'KTP', 'MKTP', 'Tinson Pen Aerodrome', NULL, 'JM', 'Kingston', 17.9886000, -76.8238000, 'active', '2026-01-31 19:27:42', '2026-01-31 19:27:42'),
(4143, 'POT', 'MKKJ', 'Ken Jones Aerodrome', NULL, 'JM', 'Portland', 18.1988000, -76.5345000, 'active', '2026-01-31 19:27:43', '2026-01-31 19:27:43'),
(4144, 'KIN', 'MKJP', 'Norman Manley International Airport', NULL, 'JM', 'Saint Andrew', 17.9357000, -76.7875000, 'active', '2026-01-31 19:27:43', '2026-01-31 19:27:43'),
(4145, 'MBJ', 'MKJS', 'Sangster International Airport', NULL, 'JM', 'Saint James', 18.5037000, -77.9134000, 'active', '2026-01-31 19:27:43', '2026-01-31 19:27:43'),
(4146, 'OCJ', 'MKBS', 'Ian Fleming International Airport', NULL, 'JM', 'Saint Mary', 18.4042000, -76.9690000, 'active', '2026-01-31 19:27:44', '2026-01-31 19:27:44'),
(4147, 'NEG', 'MKNG', 'Negril Aerodrome', NULL, 'JM', 'Westmoreland', 18.3428000, -78.3321000, 'active', '2026-01-31 19:27:44', '2026-01-31 19:27:44'),
(4148, 'AQJ', 'OJAQ', 'King Hussein International Airport', NULL, 'JO', 'Al \'Aqabah', 29.6116000, 35.0181000, 'active', '2026-01-31 19:27:44', '2026-01-31 19:27:44'),
(4149, 'ADJ', 'OJAM', 'Amman Civil Airport (Marka International Airport)', NULL, 'JO', 'Al \'Asimah', 31.9727000, 35.9916000, 'active', '2026-01-31 19:27:45', '2026-01-31 19:27:45'),
(4150, 'OMF', 'OJMF', 'King Hussein Air Base', NULL, 'JO', 'Al Mafraq', 32.3564000, 36.2592000, 'active', '2026-01-31 19:27:45', '2026-01-31 19:27:45'),
(4151, 'MPQ', 'OJMN', 'Ma\'an Airport', NULL, 'JO', 'Ma\'an', 30.1667000, 35.7833000, 'active', '2026-01-31 19:27:45', '2026-01-31 19:27:45'),
(4152, 'AMM', 'OJAI', 'Queen Alia International Airport', NULL, 'JO', 'Madaba', 31.7226000, 35.9932000, 'active', '2026-01-31 19:27:46', '2026-01-31 19:27:46'),
(4153, 'NGO', 'RJGG', 'Chubu Centrair International Airport', NULL, 'JP', 'Aichi', 34.8584000, 136.8050000, 'active', '2026-01-31 19:27:46', '2026-01-31 19:27:46'),
(4154, 'NKM', 'RJNA', 'Nagoya Airfield (Komaki Airport)', NULL, 'JP', 'Aichi', 35.2550000, 136.9240000, 'active', '2026-01-31 19:27:46', '2026-01-31 19:27:46'),
(4155, 'AXT', 'RJSK', 'Akita Airport', NULL, 'JP', 'Akita', 39.6156000, 140.2190000, 'active', '2026-01-31 19:27:47', '2026-01-31 19:27:47'),
(4156, 'ONJ', 'RJSR', 'Odate-Noshiro Airport', NULL, 'JP', 'Akita', 40.1919000, 140.3710000, 'active', '2026-01-31 19:27:47', '2026-01-31 19:27:47'),
(4157, 'AOJ', 'RJSA', 'Aomori Airport', NULL, 'JP', 'Aomori', 40.7347000, 140.6910000, 'active', '2026-01-31 19:27:47', '2026-01-31 19:27:47'),
(4158, 'HHE', 'RJSH', 'JMSDF Hachinohe Air Base', NULL, 'JP', 'Aomori', 40.5564000, 141.4660000, 'active', '2026-01-31 19:27:48', '2026-01-31 19:27:48'),
(4159, 'MSJ', 'RJSM', 'Misawa Air Base', NULL, 'JP', 'Aomori', 40.7032000, 141.3680000, 'active', '2026-01-31 19:27:48', '2026-01-31 19:27:48'),
(4160, 'MYJ', 'RJOM', 'Matsuyama Airport', NULL, 'JP', 'Ehime', 33.8272000, 132.7000000, 'active', '2026-01-31 19:27:48', '2026-01-31 19:27:48'),
(4161, 'FKJ', 'RJNF', 'Fukui Airport', NULL, 'JP', 'Fukui', 36.1428000, 136.2240000, 'active', '2026-01-31 19:27:49', '2026-01-31 19:27:49'),
(4162, 'FUK', 'RJFF', 'Fukuoka Airport (Itazuke Air Base)', NULL, 'JP', 'Fukuoka', 33.5859000, 130.4510000, 'active', '2026-01-31 19:27:49', '2026-01-31 19:27:49'),
(4163, 'KKJ', 'RJFR', 'Kitakyushu Airport', NULL, 'JP', 'Fukuoka', 33.8459000, 131.0350000, 'active', '2026-01-31 19:27:49', '2026-01-31 19:27:49'),
(4164, 'FKS', 'RJSF', 'Fukushima Airport', NULL, 'JP', 'Fukushima', 37.2274000, 140.4310000, 'active', '2026-01-31 19:27:50', '2026-01-31 19:27:50'),
(4165, 'HIJ', 'RJOA', 'Hiroshima Airport', NULL, 'JP', 'Hiroshima', 34.4361000, 132.9190000, 'active', '2026-01-31 19:27:50', '2026-01-31 19:27:50'),
(4166, 'HIW', 'RJBH', 'Hiroshima-Nishi Airport', NULL, 'JP', 'Hiroshima', 34.3669000, 132.4140000, 'active', '2026-01-31 19:27:50', '2026-01-31 19:27:50'),
(4167, 'AKJ', 'RJEC', 'Asahikawa Airport', NULL, 'JP', 'Hokkaido', 43.6708000, 142.4470000, 'active', '2026-01-31 19:27:51', '2026-01-31 19:27:51'),
(4168, 'CTS', 'RJCC', 'New Chitose Airport', NULL, 'JP', 'Hokkaido', 42.7876000, 141.6772000, 'active', '2026-01-31 19:27:51', '2026-01-31 19:27:51'),
(4169, 'HKD', 'RJCH', 'Hakodate Airport', NULL, 'JP', 'Hokkaido', 41.7700000, 140.8220000, 'active', '2026-01-31 19:27:51', '2026-01-31 19:27:51'),
(4170, 'KUH', 'RJCK', 'Kushiro Airport', NULL, 'JP', 'Hokkaido', 43.0410000, 144.1930000, 'active', '2026-01-31 19:27:52', '2026-01-31 19:27:52'),
(4171, 'MBE', 'RJEB', 'Monbetsu Airport', NULL, 'JP', 'Hokkaido', 44.3039000, 143.4040000, 'active', '2026-01-31 19:27:52', '2026-01-31 19:27:52'),
(4172, 'MMB', 'RJCM', 'Memanbetsu Airport', NULL, 'JP', 'Hokkaido', 43.8806000, 144.1640000, 'active', '2026-01-31 19:27:52', '2026-01-31 19:27:52'),
(4173, 'OBO', 'RJCB', 'Tokachi-Obihiro Airport', NULL, 'JP', 'Hokkaido', 42.7333000, 143.2170000, 'active', '2026-01-31 19:27:53', '2026-01-31 19:27:53'),
(4174, 'OIR', 'RJEO', 'Okushiri Airport', NULL, 'JP', 'Hokkaido', 42.0717000, 139.4330000, 'active', '2026-01-31 19:27:53', '2026-01-31 19:27:53'),
(4175, 'OKD', 'RJCO', 'Sapporo Okadama Airport', NULL, 'JP', 'Hokkaido', 43.1157000, 141.3800000, 'active', '2026-01-31 19:27:53', '2026-01-31 19:27:53'),
(4176, 'RBJ', 'RJCR', 'Rebun Airport', NULL, 'JP', 'Hokkaido', 45.4550000, 141.0390000, 'active', '2026-01-31 19:27:54', '2026-01-31 19:27:54'),
(4177, 'RIS', 'RJER', 'Rishiri Airport', NULL, 'JP', 'Hokkaido', 45.2420000, 141.1860000, 'active', '2026-01-31 19:27:54', '2026-01-31 19:27:54'),
(4178, 'SHB', 'RJCN', 'Nakashibetsu Airport', NULL, 'JP', 'Hokkaido', 43.5775000, 144.9600000, 'active', '2026-01-31 19:27:54', '2026-01-31 19:27:54'),
(4179, 'WKJ', 'RJCW', 'Wakkanai Airport', NULL, 'JP', 'Hokkaido', 45.4042000, 141.8010000, 'active', '2026-01-31 19:27:55', '2026-01-31 19:27:55'),
(4180, 'TJH', 'RJBT', 'Tajima Airport', NULL, 'JP', 'Hyogo', 35.5128000, 134.7870000, 'active', '2026-01-31 19:27:55', '2026-01-31 19:27:55'),
(4181, 'IBR', 'RJAH', 'Ibaraki Airport', NULL, 'JP', 'Ibaraki', 36.1811000, 140.4150000, 'active', '2026-01-31 19:27:55', '2026-01-31 19:27:55'),
(4182, 'KMQ', 'RJNK', 'Komatsu Airport (Kanazawa Airport)', NULL, 'JP', 'Ishikawa', 36.3946000, 136.4070000, 'active', '2026-01-31 19:27:56', '2026-01-31 19:27:56'),
(4183, 'NTQ', 'RJNW', 'Noto Airport', NULL, 'JP', 'Ishikawa', 37.2931000, 136.9620000, 'active', '2026-01-31 19:27:56', '2026-01-31 19:27:56'),
(4184, 'HNA', 'RJSI', 'Hanamaki Airport', NULL, 'JP', 'Iwate', 39.4286000, 141.1350000, 'active', '2026-01-31 19:27:57', '2026-01-31 19:27:57'),
(4185, 'TAK', 'RJOT', 'Takamatsu Airport', NULL, 'JP', 'Kagawa', 34.2142000, 134.0160000, 'active', '2026-01-31 19:27:57', '2026-01-31 19:27:57'),
(4186, 'ASJ', 'RJKA', 'Amami Airport', NULL, 'JP', 'Kagoshima', 28.4306000, 129.7130000, 'active', '2026-01-31 19:27:57', '2026-01-31 19:27:57'),
(4187, 'KKX', 'RJKI', 'Kikai Airport (Kikaiga Shima Airport)', NULL, 'JP', 'Kagoshima', 28.3213000, 129.9280000, 'active', '2026-01-31 19:27:58', '2026-01-31 19:27:58'),
(4188, 'KOJ', 'RJFK', 'Kagoshima Airport', NULL, 'JP', 'Kagoshima', 31.8034000, 130.7190000, 'active', '2026-01-31 19:27:58', '2026-01-31 19:27:58'),
(4189, 'KUM', 'RJFC', 'Yakushima Airport', NULL, 'JP', 'Kagoshima', 30.3856000, 130.6590000, 'active', '2026-01-31 19:27:58', '2026-01-31 19:27:58'),
(4190, 'OKE', 'RJKB', 'Okinoerabu Airport', NULL, 'JP', 'Kagoshima', 27.4255000, 128.7010000, 'active', '2026-01-31 19:27:59', '2026-01-31 19:27:59'),
(4191, 'RNJ', 'RORY', 'Yoron Airport', NULL, 'JP', 'Kagoshima', 27.0440000, 128.4020000, 'active', '2026-01-31 19:27:59', '2026-01-31 19:27:59'),
(4192, 'TKN', 'RJKN', 'Tokunoshima Airport', NULL, 'JP', 'Kagoshima', 27.8364000, 128.8810000, 'active', '2026-01-31 19:27:59', '2026-01-31 19:27:59'),
(4193, 'TNE', 'RJFG', 'New Tanegashima Airport', NULL, 'JP', 'Kagoshima', 30.6051000, 130.9910000, 'active', '2026-01-31 19:28:00', '2026-01-31 19:28:00'),
(4194, 'NJA', 'RJTA', 'Naval Air Facility Atsugi', NULL, 'JP', 'Kanagawa', 35.4546000, 139.4500000, 'active', '2026-01-31 19:28:00', '2026-01-31 19:28:00'),
(4195, 'UKB', 'RJBE', 'Kobe Airport', NULL, 'JP', 'Kobe', 34.6354000, 135.2261000, 'active', '2026-01-31 19:28:00', '2026-01-31 19:28:00'),
(4196, 'KCZ', 'RJOK', 'Kochi Ryoma Airport', NULL, 'JP', 'Kochi', 33.5461000, 133.6690000, 'active', '2026-01-31 19:28:01', '2026-01-31 19:28:01'),
(4197, 'AXJ', 'RJDA', 'Amakusa Airfield', NULL, 'JP', 'Kumamoto', 32.4825000, 130.1590000, 'active', '2026-01-31 19:28:02', '2026-01-31 19:28:02'),
(4198, 'KMJ', 'RJFT', 'Kumamoto Airport', NULL, 'JP', 'Kumamoto', 32.8373000, 130.8550000, 'active', '2026-01-31 19:28:03', '2026-01-31 19:28:03');
INSERT INTO `iata_codes` (`id`, `code`, `icao`, `airport`, `city`, `country_code`, `region_name`, `latitude`, `longitude`, `status`, `created_at`, `updated_at`) VALUES
(4199, 'SDJ', 'RJSS', 'Sendai Airport', NULL, 'JP', 'Miyagi', 38.1397000, 140.9170000, 'active', '2026-01-31 19:28:03', '2026-01-31 19:28:03'),
(4200, 'KMI', 'RJFM', 'Miyazaki Airport', NULL, 'JP', 'Miyazaki', 31.8772000, 131.4490000, 'active', '2026-01-31 19:28:04', '2026-01-31 19:28:04'),
(4201, 'MMJ', 'RJAF', 'Matsumoto Airport', NULL, 'JP', 'Nagano', 36.1668000, 137.9230000, 'active', '2026-01-31 19:28:04', '2026-01-31 19:28:04'),
(4202, 'FUJ', 'RJFE', 'Fukue Airport (Goto-Fukue Airport)', NULL, 'JP', 'Nagasaki', 32.6663000, 128.8330000, 'active', '2026-01-31 19:28:04', '2026-01-31 19:28:04'),
(4203, 'IKI', 'RJDB', 'Iki Airport', NULL, 'JP', 'Nagasaki', 33.7490000, 129.7850000, 'active', '2026-01-31 19:28:05', '2026-01-31 19:28:05'),
(4204, 'NGS', 'RJFU', 'Nagasaki Airport', NULL, 'JP', 'Nagasaki', 32.9169000, 129.9140000, 'active', '2026-01-31 19:28:05', '2026-01-31 19:28:05'),
(4205, 'OMJ', 'RJDU', 'Omura Airport', NULL, 'JP', 'Nagasaki', 35.0833000, 140.1000000, 'active', '2026-01-31 19:28:05', '2026-01-31 19:28:05'),
(4206, 'TSJ', 'RJDT', 'Tsushima Airport', NULL, 'JP', 'Nagasaki', 34.2849000, 129.3310000, 'active', '2026-01-31 19:28:06', '2026-01-31 19:28:06'),
(4207, 'KIJ', 'RJSN', 'Niigata Airport', NULL, 'JP', 'Niigata', 37.9559000, 139.1210000, 'active', '2026-01-31 19:28:06', '2026-01-31 19:28:06'),
(4208, 'SDS', 'RJSD', 'Sado Airport', NULL, 'JP', 'Niigata', 38.0602000, 138.4140000, 'active', '2026-01-31 19:28:08', '2026-01-31 19:28:08'),
(4209, 'OIT', 'RJFO', 'Oita Airport', NULL, 'JP', 'Oita', 33.4794000, 131.7370000, 'active', '2026-01-31 19:28:10', '2026-01-31 19:28:10'),
(4210, 'OKJ', 'RJOB', 'Okayama Airport', NULL, 'JP', 'Okayama', 34.7569000, 133.8550000, 'active', '2026-01-31 19:28:10', '2026-01-31 19:28:10'),
(4211, 'AGJ', 'RORA', 'Aguni Airport', NULL, 'JP', 'Okinawa', 26.5925000, 127.2410000, 'active', '2026-01-31 19:28:11', '2026-01-31 19:28:11'),
(4212, 'DNA', 'RODN', 'Kadena Air Base', NULL, 'JP', 'Okinawa', 26.3556000, 127.7680000, 'active', '2026-01-31 19:28:11', '2026-01-31 19:28:11'),
(4213, 'HTR', 'RORH', 'Hateruma Airport', NULL, 'JP', 'Okinawa', 24.0589000, 123.8060000, 'active', '2026-01-31 19:28:11', '2026-01-31 19:28:11'),
(4214, 'IEJ', 'RORE', 'Iejima Airport', NULL, 'JP', 'Okinawa', 26.7220000, 127.7850000, 'active', '2026-01-31 19:28:12', '2026-01-31 19:28:12'),
(4215, 'ISG', 'ROIG', 'New Ishigaki Airport', NULL, 'JP', 'Okinawa', 24.3964000, 124.2450000, 'active', '2026-01-31 19:28:12', '2026-01-31 19:28:12'),
(4216, 'KJP', 'ROKR', 'Kerama Airport', NULL, 'JP', 'Okinawa', 26.1683000, 127.2930000, 'active', '2026-01-31 19:28:12', '2026-01-31 19:28:12'),
(4217, 'KTD', 'RORK', 'Kitadaito Airport', NULL, 'JP', 'Okinawa', 25.9447000, 131.3270000, 'active', '2026-01-31 19:28:13', '2026-01-31 19:28:13'),
(4218, 'MMD', 'ROMD', 'Minami-Daito Airport', NULL, 'JP', 'Okinawa', 25.8465000, 131.2630000, 'active', '2026-01-31 19:28:13', '2026-01-31 19:28:13'),
(4219, 'MMY', 'ROMY', 'Miyako Airport', NULL, 'JP', 'Okinawa', 24.7828000, 125.2950000, 'active', '2026-01-31 19:28:13', '2026-01-31 19:28:13'),
(4220, 'OGN', 'ROYN', 'Yonaguni Airport', NULL, 'JP', 'Okinawa', 24.4669000, 122.9780000, 'active', '2026-01-31 19:28:14', '2026-01-31 19:28:14'),
(4221, 'OKA', 'ROAH', 'Naha Airport', NULL, 'JP', 'Okinawa', 26.1958000, 127.6460000, 'active', '2026-01-31 19:28:14', '2026-01-31 19:28:14'),
(4222, 'SHI', 'RORS', 'Shimojishima Airport', NULL, 'JP', 'Okinawa', 24.8267000, 125.1450000, 'active', '2026-01-31 19:28:14', '2026-01-31 19:28:14'),
(4223, 'TRA', 'RORT', 'Tarama Airport', NULL, 'JP', 'Okinawa', 24.6539000, 124.6750000, 'active', '2026-01-31 19:28:15', '2026-01-31 19:28:15'),
(4224, 'UEO', 'ROKJ', 'Kumejima Airport', NULL, 'JP', 'Okinawa', 26.3635000, 126.7140000, 'active', '2026-01-31 19:28:15', '2026-01-31 19:28:15'),
(4225, 'KIX', 'RJBB', 'Kansai International Airport', NULL, 'JP', 'Osaka', 34.4305000, 135.2300000, 'active', '2026-01-31 19:28:15', '2026-01-31 19:28:15'),
(4226, 'ITM', 'RJOO', 'Osaka Itami International Airport', NULL, 'JP', 'Osaka', 34.7868000, 135.4387000, 'active', '2026-01-31 19:28:16', '2026-01-31 19:28:16'),
(4227, 'HSG', 'RJFS', 'Saga Airport', NULL, 'JP', 'Saga', 33.1497000, 130.3020000, 'active', '2026-01-31 19:28:16', '2026-01-31 19:28:16'),
(4228, 'IWJ', 'RJOW', 'Iwami Airport (Hagi-Iwami Airport)', NULL, 'JP', 'Shimane', 34.6764000, 131.7900000, 'active', '2026-01-31 19:28:16', '2026-01-31 19:28:16'),
(4229, 'IZO', 'RJOC', 'Izumo Airport', NULL, 'JP', 'Shimane', 35.4136000, 132.8900000, 'active', '2026-01-31 19:28:17', '2026-01-31 19:28:17'),
(4230, 'FSZ', 'RJNS', 'Shizuoka Airport (Mt. Fuji Shizuoka Airport)', NULL, 'JP', 'Shizuoka', 34.7960000, 138.1880000, 'active', '2026-01-31 19:28:17', '2026-01-31 19:28:17'),
(4231, 'TKS', 'RJOS', 'Tokushima Airport', NULL, 'JP', 'Tokushima', 34.1328000, 134.6070000, 'active', '2026-01-31 19:28:17', '2026-01-31 19:28:17'),
(4232, 'HAC', 'RJTH', 'Hachijojima Airport', NULL, 'JP', 'Tokyo', 33.1150000, 139.7860000, 'active', '2026-01-31 19:28:18', '2026-01-31 19:28:18'),
(4233, 'HND', 'RJTT', 'Haneda Airport', NULL, 'JP', 'Tokyo', 35.5533000, 139.7810000, 'active', '2026-01-31 19:28:18', '2026-01-31 19:28:18'),
(4234, 'IWO', 'RJAW', 'Iwo Jima Air Base', NULL, 'JP', 'Tokyo', 24.7840000, 141.3230000, 'active', '2026-01-31 19:28:18', '2026-01-31 19:28:18'),
(4235, 'MUS', 'RJAM', 'Minami Torishima Airport', NULL, 'JP', 'Tokyo', 24.2897000, 153.9790000, 'active', '2026-01-31 19:28:19', '2026-01-31 19:28:19'),
(4236, 'MYE', 'RJTQ', 'Miyakejima Airport', NULL, 'JP', 'Tokyo', 34.0736000, 139.5600000, 'active', '2026-01-31 19:28:19', '2026-01-31 19:28:19'),
(4237, 'NRT', 'RJAA', 'Narita International Airport', NULL, 'JP', 'Tokyo', 35.7653000, 140.3860000, 'active', '2026-01-31 19:28:19', '2026-01-31 19:28:19'),
(4238, 'OIM', 'RJTO', 'Oshima Airport', NULL, 'JP', 'Tokyo', 34.7820000, 139.3600000, 'active', '2026-01-31 19:28:20', '2026-01-31 19:28:20'),
(4239, 'OKI', 'RJNO', 'Oki Airport', NULL, 'JP', 'Tottori', 36.1811000, 133.3250000, 'active', '2026-01-31 19:28:20', '2026-01-31 19:28:20'),
(4240, 'TTJ', 'RJOR', 'Tottori Airport', NULL, 'JP', 'Tottori', 35.5301000, 134.1670000, 'active', '2026-01-31 19:28:20', '2026-01-31 19:28:20'),
(4241, 'YGJ', 'RJOH', 'Miho-Yonago Airport', NULL, 'JP', 'Tottori', 35.4922000, 133.2360000, 'active', '2026-01-31 19:28:21', '2026-01-31 19:28:21'),
(4242, 'TOY', 'RJNT', 'Toyama Airport', NULL, 'JP', 'Toyama', 36.6483000, 137.1880000, 'active', '2026-01-31 19:28:21', '2026-01-31 19:28:21'),
(4243, 'SHM', 'RJBD', 'Nanki-Shirahama Airport', NULL, 'JP', 'Wakayama', 33.6622000, 135.3640000, 'active', '2026-01-31 19:28:21', '2026-01-31 19:28:21'),
(4244, 'GAJ', 'RJSC', 'Yamagata Airport (Junmachi Airport)', NULL, 'JP', 'Yamagata', 38.4119000, 140.3710000, 'active', '2026-01-31 19:28:22', '2026-01-31 19:28:22'),
(4245, 'SYO', 'RJSY', 'Shonai Airport', NULL, 'JP', 'Yamagata', 38.8122000, 139.7870000, 'active', '2026-01-31 19:28:22', '2026-01-31 19:28:22'),
(4246, 'IWK', 'RJOI', 'Marine Corps Air Station Iwakuni', NULL, 'JP', 'Yamaguchi', 34.1439000, 132.2360000, 'active', '2026-01-31 19:28:22', '2026-01-31 19:28:22'),
(4247, 'UBJ', 'RJDC', 'Yamaguchi Ube Airport', NULL, 'JP', 'Yamaguchi', 33.9300000, 131.2790000, 'active', '2026-01-31 19:28:23', '2026-01-31 19:28:23'),
(4248, 'LBN', NULL, 'Lake Baringo Airport', NULL, 'KE', 'Baringo', 0.6661030, 36.1042000, 'active', '2026-01-31 19:28:23', '2026-01-31 19:28:23'),
(4249, 'KRV', NULL, 'Kimwarer Airport (Kerio Valley Airport)', NULL, 'KE', 'Elgeyo/Marakwet', 0.3196380, 35.6626000, 'active', '2026-01-31 19:28:23', '2026-01-31 19:28:23'),
(4250, 'NBO', 'HKJK', 'Jomo Kenyatta International Airport', NULL, 'KE', 'Elgeyo/Marakwet', -1.3192400, 36.9278000, 'active', '2026-01-31 19:28:24', '2026-01-31 19:28:24'),
(4251, 'GAS', 'HKGA', 'Garissa Airport', NULL, 'KE', 'Garissa', -0.4635080, 39.6483000, 'active', '2026-01-31 19:28:24', '2026-01-31 19:28:24'),
(4252, 'LBK', NULL, 'Liboi Airport', NULL, 'KE', 'Garissa', 0.3483330, 40.8817000, 'active', '2026-01-31 19:28:24', '2026-01-31 19:28:24'),
(4253, 'ASV', 'HKAM', 'Amboseli Airport', NULL, 'KE', 'Kajiado', -2.6450500, 37.2531000, 'active', '2026-01-31 19:28:25', '2026-01-31 19:28:25'),
(4254, 'GGM', 'HKKG', 'Kakamega Airport', NULL, 'KE', 'Kakamega', 0.2713420, 34.7873000, 'active', '2026-01-31 19:28:25', '2026-01-31 19:28:25'),
(4255, 'KEY', 'HKKR', 'Kericho Airport', NULL, 'KE', 'Kericho', -0.3899000, 35.2421000, 'active', '2026-01-31 19:28:25', '2026-01-31 19:28:25'),
(4256, 'MYD', 'HKML', 'Malindi Airport', NULL, 'KE', 'Kilifi', -3.2293100, 40.1017000, 'active', '2026-01-31 19:28:26', '2026-01-31 19:28:26'),
(4257, 'VPG', NULL, 'Vipingo Airport', NULL, 'KE', 'Kilifi', -3.8066700, 39.7974000, 'active', '2026-01-31 19:28:26', '2026-01-31 19:28:26'),
(4258, 'KIS', 'HKKI', 'Kisumu International Airport', NULL, 'KE', 'Kisumu', -0.0861390, 34.7289000, 'active', '2026-01-31 19:28:26', '2026-01-31 19:28:26'),
(4259, 'UKA', 'HKUK', 'Ukunda Airport (Diani Airport)', NULL, 'KE', 'Kwale', -4.2933300, 39.5711000, 'active', '2026-01-31 19:28:27', '2026-01-31 19:28:27'),
(4260, 'NYK', 'HKNY', 'Nanyuki Airport', NULL, 'KE', 'Laikipia', -0.0623990, 37.0410000, 'active', '2026-01-31 19:28:27', '2026-01-31 19:28:27'),
(4261, 'KIU', NULL, 'Kiunga Airport', NULL, 'KE', 'Lamu', -1.7438300, 41.4843000, 'active', '2026-01-31 19:28:27', '2026-01-31 19:28:27'),
(4262, 'KWY', NULL, 'Kiwayu Airport', NULL, 'KE', 'Lamu', -1.9605600, 41.2975000, 'active', '2026-01-31 19:28:28', '2026-01-31 19:28:28'),
(4263, 'LAU', 'HKLU', 'Manda Airport', NULL, 'KE', 'Lamu', -2.2524200, 40.9131000, 'active', '2026-01-31 19:28:28', '2026-01-31 19:28:28'),
(4264, 'NDE', 'HKMA', 'Mandera Airport', NULL, 'KE', 'Mandera', 3.9330000, 41.8500000, 'active', '2026-01-31 19:28:28', '2026-01-31 19:28:28'),
(4265, 'OYL', 'HKMY', 'Moyale Airport', NULL, 'KE', 'Marsabit', 3.4697200, 39.1014000, 'active', '2026-01-31 19:28:29', '2026-01-31 19:28:29'),
(4266, 'RBT', 'HKMB', 'Marsabit Airport', NULL, 'KE', 'Marsabit', 2.3442500, 38.0000000, 'active', '2026-01-31 19:28:29', '2026-01-31 19:28:29'),
(4267, 'JJM', 'HKMK', 'Mulika Lodge Airport', NULL, 'KE', 'Meru', 0.1650830, 38.1951000, 'active', '2026-01-31 19:28:29', '2026-01-31 19:28:29'),
(4268, 'BMQ', NULL, 'Bamburi Airport', NULL, 'KE', 'Mombasa', -3.9819100, 39.7308000, 'active', '2026-01-31 19:28:30', '2026-01-31 19:28:30'),
(4269, 'MBA', 'HKMO', 'Moi International Airport', NULL, 'KE', 'Mombasa', -4.0348300, 39.5942000, 'active', '2026-01-31 19:28:30', '2026-01-31 19:28:30'),
(4270, 'WIL', 'HKNW', 'Wilson Airport', NULL, 'KE', 'Nairobi City', -1.3217200, 36.8148000, 'active', '2026-01-31 19:28:31', '2026-01-31 19:28:31'),
(4271, 'NUU', 'HKNK', 'Nakuru Airport', NULL, 'KE', 'Nakuru', -0.2980670, 36.1593000, 'active', '2026-01-31 19:28:31', '2026-01-31 19:28:31'),
(4272, 'KEU', 'HKKE', 'Keekorok Airport', NULL, 'KE', 'Narok', -1.5830000, 35.2500000, 'active', '2026-01-31 19:28:32', '2026-01-31 19:28:32'),
(4273, 'MRE', NULL, 'Mara Serena Airport', NULL, 'KE', 'Narok', -1.4061100, 35.0081000, 'active', '2026-01-31 19:28:32', '2026-01-31 19:28:32'),
(4274, 'ANA', NULL, 'Angama Airstrip', NULL, 'KE', 'Nyamira', -1.2715600, 34.9555000, 'active', '2026-01-31 19:28:32', '2026-01-31 19:28:32'),
(4275, 'KTJ', NULL, 'Kichwa Tembo Airport', NULL, 'KE', 'Nyamira', -1.2635000, 35.0275000, 'active', '2026-01-31 19:28:33', '2026-01-31 19:28:33'),
(4276, 'OLX', NULL, 'Olkiombo Airstrip', NULL, 'KE', 'Nyamira', -1.4085900, 35.1107000, 'active', '2026-01-31 19:28:33', '2026-01-31 19:28:33'),
(4277, 'NYE', 'HKNI', 'Nyeri Airport', NULL, 'KE', 'Nyeri', -0.3644140, 36.9785000, 'active', '2026-01-31 19:28:33', '2026-01-31 19:28:33'),
(4278, 'UAS', 'HKSB', 'Samburu Airport (Buffalo Spring Airport)', NULL, 'KE', 'Samburu', 0.5305830, 37.5342000, 'active', '2026-01-31 19:28:34', '2026-01-31 19:28:34'),
(4279, 'ILU', 'HKKL', 'Kilaguni Airport', NULL, 'KE', 'Taita/Taveta', -2.9106100, 38.0652000, 'active', '2026-01-31 19:28:34', '2026-01-31 19:28:34'),
(4280, 'HOA', 'HKHO', 'Hola Airport', NULL, 'KE', 'Tana River', -1.5220000, 40.0040000, 'active', '2026-01-31 19:28:34', '2026-01-31 19:28:34'),
(4281, 'EYS', 'HKES', 'Eliye Springs Airport', NULL, 'KE', 'Turkana', 3.2166700, 35.9667000, 'active', '2026-01-31 19:28:35', '2026-01-31 19:28:35'),
(4282, 'KLK', 'HKFG', 'Kalokol Airport (Fergusons Gulf Airport)', NULL, 'KE', 'Turkana', 3.4916100, 35.8368000, 'active', '2026-01-31 19:28:35', '2026-01-31 19:28:35'),
(4283, 'LKG', 'HKLK', 'Lokichogio Airport', NULL, 'KE', 'Turkana', 4.2041200, 34.3482000, 'active', '2026-01-31 19:28:35', '2026-01-31 19:28:35'),
(4284, 'LKU', NULL, 'Lake Turkana Airport', NULL, 'KE', 'Turkana', 3.4166700, 35.8833000, 'active', '2026-01-31 19:28:36', '2026-01-31 19:28:36'),
(4285, 'LOK', 'HKLO', 'Lodwar Airport', NULL, 'KE', 'Turkana', 3.1219700, 35.6087000, 'active', '2026-01-31 19:28:36', '2026-01-31 19:28:36'),
(4286, 'LOY', 'HKLY', 'Loiyangalani Airport', NULL, 'KE', 'Turkana', 2.7500000, 36.7170000, 'active', '2026-01-31 19:28:36', '2026-01-31 19:28:36'),
(4287, 'EDL', 'HKEL', 'Eldoret International Airport', NULL, 'KE', 'Uasin Gishu', 0.4044580, 35.2389000, 'active', '2026-01-31 19:28:37', '2026-01-31 19:28:37'),
(4288, 'KTL', 'HKKT', 'Kitale Airport', NULL, 'KE', 'Uasin Gishu', 0.9719890, 34.9586000, 'active', '2026-01-31 19:28:37', '2026-01-31 19:28:37'),
(4289, 'WJR', 'HKWJ', 'Wajir Airport', NULL, 'KE', 'Wajir', 1.7332400, 40.0916000, 'active', '2026-01-31 19:28:37', '2026-01-31 19:28:37'),
(4290, 'FRU', 'UAFM', 'Manas International Airport', NULL, 'KG', 'Chuy', 43.0613000, 74.4776000, 'active', '2026-01-31 19:28:38', '2026-01-31 19:28:38'),
(4291, 'OSS', 'UAFO', 'Osh Airport', NULL, 'KG', 'Osh', 40.6090000, 72.7933000, 'active', '2026-01-31 19:28:38', '2026-01-31 19:28:38'),
(4292, 'IKU', 'UCFL', 'Issyk-Kul International Airport', NULL, 'KG', 'Issyk-Kul', 42.5851000, 76.7064000, 'active', '2026-01-31 19:28:38', '2026-01-31 19:28:38'),
(4293, 'BBM', 'VDBG', 'Battambang Airport', NULL, 'KH', 'Baat Dambang', 13.0956000, 103.2240000, 'active', '2026-01-31 19:28:39', '2026-01-31 19:28:39'),
(4294, 'KZC', 'VDKH', 'Kampong Chhnang Airport', NULL, 'KH', 'Kampong Chhnang', 12.2552000, 104.5640000, 'active', '2026-01-31 19:28:39', '2026-01-31 19:28:39'),
(4295, 'KMT', NULL, 'Kampot Airport', NULL, 'KH', 'Kampot', 10.6343000, 104.1620000, 'active', '2026-01-31 19:28:39', '2026-01-31 19:28:39'),
(4296, 'KKZ', 'VDKK', 'Koh Kong Airport', NULL, 'KH', 'Kaoh Kong', 11.6134000, 102.9970000, 'active', '2026-01-31 19:28:40', '2026-01-31 19:28:40'),
(4297, 'KTI', 'VDKT', 'Kratie Airport', NULL, 'KH', 'Kracheh', 12.4880000, 106.0550000, 'active', '2026-01-31 19:28:40', '2026-01-31 19:28:40'),
(4298, 'KOS', 'VDSV', 'Sihanoukville International Airport (Kaong Kang Airport)', NULL, 'KH', 'Krong Preah Sihanouk', 10.5797000, 103.6370000, 'active', '2026-01-31 19:28:40', '2026-01-31 19:28:40'),
(4299, 'MWV', 'VDMK', 'Mondulkiri Airport', NULL, 'KH', 'Mondol Kiri', 12.4636000, 107.1870000, 'active', '2026-01-31 19:28:41', '2026-01-31 19:28:41'),
(4300, 'PNH', 'VDPP', 'Phnom Penh International Airport', NULL, 'KH', 'Phnom Penh', 11.5466000, 104.8440000, 'active', '2026-01-31 19:28:41', '2026-01-31 19:28:41'),
(4301, 'TNX', 'VDST', 'Steung Treng Airport', NULL, 'KH', 'Phnom Penh', 13.5319000, 106.0150000, 'active', '2026-01-31 19:28:41', '2026-01-31 19:28:41'),
(4302, 'KZD', NULL, 'Krakor Airport', NULL, 'KH', 'Pousaat', 12.5385000, 104.1490000, 'active', '2026-01-31 19:28:42', '2026-01-31 19:28:42'),
(4303, 'OMY', NULL, 'Thbeng Meanchey Airport (Preah Vinhear Airport)', NULL, 'KH', 'Preah Vihear', 13.7597000, 104.9720000, 'active', '2026-01-31 19:28:42', '2026-01-31 19:28:42'),
(4304, 'RBE', 'VDRK', 'Ratanakiri Airport', NULL, 'KH', 'Rotanak Kiri', 13.7300000, 106.9870000, 'active', '2026-01-31 19:28:42', '2026-01-31 19:28:42'),
(4305, 'REP', 'VDSR', 'Siem Reap International Airport (Angkor Int\'l)', NULL, 'KH', 'Siem Reab', 13.4107000, 103.8130000, 'active', '2026-01-31 19:28:43', '2026-01-31 19:28:43'),
(4306, 'SAI', 'VDSA', 'Siem Reap Angkor International Airport', NULL, 'KH', 'Siem Reab', 13.3758000, 104.2197000, 'active', '2026-01-31 19:28:43', '2026-01-31 19:28:43'),
(4307, 'AAK', 'NGUK', 'Aranuka Airport', NULL, 'KI', 'Gilbert Islands', 0.1852780, 173.6370000, 'active', '2026-01-31 19:28:43', '2026-01-31 19:28:43'),
(4308, 'ABF', 'NGAB', 'Abaiang Atoll Airport', NULL, 'KI', 'Gilbert Islands', 1.7986100, 173.0410000, 'active', '2026-01-31 19:28:44', '2026-01-31 19:28:44'),
(4309, 'AEA', 'NGTB', 'Abemama Atoll Airport', NULL, 'KI', 'Gilbert Islands', 0.4908330, 173.8290000, 'active', '2026-01-31 19:28:44', '2026-01-31 19:28:44'),
(4310, 'AIS', 'NGTR', 'Arorae Island Airport', NULL, 'KI', 'Gilbert Islands', -2.6161100, 176.8030000, 'active', '2026-01-31 19:28:44', '2026-01-31 19:28:44'),
(4311, 'BBG', 'NGTU', 'Butaritari Atoll Airport', NULL, 'KI', 'Gilbert Islands', 3.0858300, 172.8110000, 'active', '2026-01-31 19:28:45', '2026-01-31 19:28:45'),
(4312, 'BEZ', 'NGBR', 'Beru Island Airport', NULL, 'KI', 'Gilbert Islands', -1.3547200, 176.0070000, 'active', '2026-01-31 19:28:45', '2026-01-31 19:28:45'),
(4313, 'KUC', 'NGKT', 'Kuria Airport', NULL, 'KI', 'Gilbert Islands', 0.2186110, 173.4420000, 'active', '2026-01-31 19:28:45', '2026-01-31 19:28:45'),
(4314, 'MNK', 'NGMA', 'Maiana Airport', NULL, 'KI', 'Gilbert Islands', 1.0036100, 173.0310000, 'active', '2026-01-31 19:28:46', '2026-01-31 19:28:46'),
(4315, 'MTK', 'NGMN', 'Makin Airport', NULL, 'KI', 'Gilbert Islands', 3.3744400, 172.9920000, 'active', '2026-01-31 19:28:46', '2026-01-31 19:28:46'),
(4316, 'MZK', 'NGMK', 'Marakei Airport', NULL, 'KI', 'Gilbert Islands', 2.0586100, 173.2710000, 'active', '2026-01-31 19:28:46', '2026-01-31 19:28:46'),
(4317, 'NIG', 'NGNU', 'Nikunau Airport', NULL, 'KI', 'Gilbert Islands', -1.3144400, 176.4100000, 'active', '2026-01-31 19:28:47', '2026-01-31 19:28:47'),
(4318, 'NON', 'NGTO', 'Nonouti Airport', NULL, 'KI', 'Gilbert Islands', -0.6397220, 174.4280000, 'active', '2026-01-31 19:28:47', '2026-01-31 19:28:47'),
(4319, 'OOT', 'NGON', 'Onotoa Airport', NULL, 'KI', 'Gilbert Islands', -1.7961100, 175.5260000, 'active', '2026-01-31 19:28:47', '2026-01-31 19:28:47'),
(4320, 'TBF', 'NGTE', 'Tabiteuea North Airport', NULL, 'KI', 'Gilbert Islands', -1.2244700, 174.7760000, 'active', '2026-01-31 19:28:48', '2026-01-31 19:28:48'),
(4321, 'TMN', 'NGTM', 'Tamana Airport', NULL, 'KI', 'Gilbert Islands', -2.4858300, 175.9700000, 'active', '2026-01-31 19:28:48', '2026-01-31 19:28:48'),
(4322, 'TRW', 'NGTA', 'Bonriki International Airport', NULL, 'KI', 'Gilbert Islands', 1.3816400, 173.1470000, 'active', '2026-01-31 19:28:48', '2026-01-31 19:28:48'),
(4323, 'TSU', 'NGTS', 'Tabiteuea South Airport', NULL, 'KI', 'Gilbert Islands', -1.4744400, 175.0640000, 'active', '2026-01-31 19:28:49', '2026-01-31 19:28:49'),
(4324, 'CIS', 'PCIS', 'Canton Island Airport', NULL, 'KI', 'Line Islands', -2.7681200, -171.7100000, 'active', '2026-01-31 19:28:49', '2026-01-31 19:28:49'),
(4325, 'CXI', 'PLCH', 'Cassidy International Airport', NULL, 'KI', 'Line Islands', 1.9861600, -157.3500000, 'active', '2026-01-31 19:28:49', '2026-01-31 19:28:49'),
(4326, 'TNQ', NULL, 'Teraina Airport', NULL, 'KI', 'Line Islands', 4.6983600, -160.3940000, 'active', '2026-01-31 19:28:50', '2026-01-31 19:28:50'),
(4327, 'TNV', NULL, 'Tabuaeran Island Airport', NULL, 'KI', 'Line Islands', 3.8994400, -159.3890000, 'active', '2026-01-31 19:28:50', '2026-01-31 19:28:50'),
(4328, 'AJN', 'FMCV', 'Ouani Airport', NULL, 'KM', 'Anjouan', -12.1317000, 44.4303000, 'active', '2026-01-31 19:28:50', '2026-01-31 19:28:50'),
(4329, 'HAH', 'FMCH', 'Prince Said Ibrahim International Airport', NULL, 'KM', 'Grande Comore', -11.5337000, 43.2719000, 'active', '2026-01-31 19:28:51', '2026-01-31 19:28:51'),
(4330, 'YVA', 'FMCN', 'Iconi Airport', NULL, 'KM', 'Grande Comore', -11.7125000, 43.2431000, 'active', '2026-01-31 19:28:51', '2026-01-31 19:28:51'),
(4331, 'NWA', 'FMCI', 'Moheli Bandar Es Eslam Airport', NULL, 'KM', 'Moheli', -12.2981000, 43.7664000, 'active', '2026-01-31 19:28:51', '2026-01-31 19:28:51'),
(4332, 'SKB', 'TKPK', 'Robert L. Bradshaw International Airport', NULL, 'KN', 'Saint John Figtree', 17.3112000, -62.7187000, 'active', '2026-01-31 19:28:52', '2026-01-31 19:28:52'),
(4333, 'NEV', 'TKPN', 'Vance W. Amory International Airport', NULL, 'KN', 'Saint Paul Charlestown', 17.2057000, -62.5899000, 'active', '2026-01-31 19:28:52', '2026-01-31 19:28:52'),
(4334, 'RGO', 'ZKHM', 'Orang Airport', NULL, 'KP', 'Hamgyong-bukto', 41.4285000, 129.6480000, 'active', '2026-01-31 19:28:52', '2026-01-31 19:28:52'),
(4335, 'DSO', 'ZKSD', 'Sondok Airport', NULL, 'KP', 'Hwanghae-namdo', 39.7452000, 127.4740000, 'active', '2026-01-31 19:28:53', '2026-01-31 19:28:53'),
(4336, 'WOS', 'ZKWS', 'Wonsan Kalma International Airport', NULL, 'KP', 'Kangwon-do', 39.1668000, 127.4860000, 'active', '2026-01-31 19:28:53', '2026-01-31 19:28:53'),
(4337, 'UJU', 'ZKUJ', 'Uiju Airfield', NULL, 'KP', 'P\'yongan-bukto', 40.1546000, 124.5320000, 'active', '2026-01-31 19:28:54', '2026-01-31 19:28:54'),
(4338, 'FNJ', 'ZKPY', 'Pyongyang Sunan International Airport', NULL, 'KP', 'P\'yongyang', 39.2241000, 125.6700000, 'active', '2026-01-31 19:28:54', '2026-01-31 19:28:54'),
(4339, 'YJS', 'ZKSE', 'Samjiyon Airport', NULL, 'KP', 'Ryanggang-do', 41.9071000, 128.4100000, 'active', '2026-01-31 19:28:54', '2026-01-31 19:28:54'),
(4340, 'PUS', 'RKPK', 'Gimhae International Airport', NULL, 'KR', 'Busan-gwangyeoksi', 35.1795000, 128.9380000, 'active', '2026-01-31 19:28:55', '2026-01-31 19:28:55'),
(4341, 'CJJ', 'RKTU', 'Cheongju International Airport', NULL, 'KR', 'Chungcheongbuk-do', 36.7170000, 127.4990000, 'active', '2026-01-31 19:28:55', '2026-01-31 19:28:55'),
(4342, 'JWO', 'RKTI', 'Jungwon Air Base', NULL, 'KR', 'Chungcheongbuk-do', 37.0300000, 127.8850000, 'active', '2026-01-31 19:28:55', '2026-01-31 19:28:55'),
(4343, 'HMY', 'RKTP', 'Seosan Air Base', NULL, 'KR', 'Chungcheongnam-do', 36.7040000, 126.4860000, 'active', '2026-01-31 19:28:56', '2026-01-31 19:28:56'),
(4344, 'KAG', 'RKNN', 'Gangneung Air Base', NULL, 'KR', 'Gangwon-do', 37.7536000, 128.9440000, 'active', '2026-01-31 19:28:56', '2026-01-31 19:28:56'),
(4345, 'WJU', 'RKNW', 'Wonju Airport', NULL, 'KR', 'Gangwon-do', 37.4412000, 127.9640000, 'active', '2026-01-31 19:28:56', '2026-01-31 19:28:56'),
(4346, 'YNY', 'RKNY', 'Yangyang International Airport', NULL, 'KR', 'Gangwon-do', 38.0613000, 128.6690000, 'active', '2026-01-31 19:28:57', '2026-01-31 19:28:57'),
(4347, 'CHN', 'RKJU', 'Jeonju Airport', NULL, 'KR', 'Gwangju-gwangyeoksi', 35.8781000, 127.1190000, 'active', '2026-01-31 19:28:57', '2026-01-31 19:28:57'),
(4348, 'KUV', 'RKJK', 'Gunsan Airport', NULL, 'KR', 'Gwangju-gwangyeoksi', 35.9038000, 126.6160000, 'active', '2026-01-31 19:28:57', '2026-01-31 19:28:57'),
(4349, 'KWJ', 'RKJJ', 'Gwangju Airport', NULL, 'KR', 'Gwangju-gwangyeoksi', 35.1232000, 126.8050000, 'active', '2026-01-31 19:28:58', '2026-01-31 19:28:58'),
(4350, 'MWX', 'RKJB', 'Muan International Airport', NULL, 'KR', 'Gwangju-gwangyeoksi', 34.9914000, 126.3830000, 'active', '2026-01-31 19:28:58', '2026-01-31 19:28:58'),
(4351, 'RSU', 'RKJY', 'Yeosu/Suncheon Airport', NULL, 'KR', 'Gwangju-gwangyeoksi', 34.8423000, 127.6170000, 'active', '2026-01-31 19:28:58', '2026-01-31 19:28:58'),
(4352, 'GMP', 'RKSS', 'Seoul Gimpo International Airport', NULL, 'KR', 'Gyeonggi-do', 37.5655000, 126.8011000, 'active', '2026-01-31 19:28:59', '2026-01-31 19:28:59'),
(4353, 'ICN', 'RKSI', 'Incheon International Airport', NULL, 'KR', 'Gyeonggi-do', 37.4633000, 126.4400000, 'active', '2026-01-31 19:28:59', '2026-01-31 19:28:59'),
(4354, 'OSN', 'RKSO', 'Osan Air Base', NULL, 'KR', 'Gyeonggi-do', 37.0906000, 127.0300000, 'active', '2026-01-31 19:28:59', '2026-01-31 19:28:59'),
(4355, 'SWU', 'RKSW', 'Suwon Air Base', NULL, 'KR', 'Gyeonggi-do', 37.2394000, 127.0070000, 'active', '2026-01-31 19:29:00', '2026-01-31 19:29:00'),
(4356, 'CHF', 'RKPE', 'Jinhae Airport', NULL, 'KR', 'Gyeongsangnam-do', 35.1402000, 128.6960000, 'active', '2026-01-31 19:29:00', '2026-01-31 19:29:00'),
(4357, 'HIN', 'RKPS', 'Sacheon Airport', NULL, 'KR', 'Gyeongsangnam-do', 35.0886000, 128.0720000, 'active', '2026-01-31 19:29:00', '2026-01-31 19:29:00'),
(4358, 'KPO', 'RKTH', 'Pohang Airport', NULL, 'KR', 'Gyeongsangnam-do', 35.9880000, 129.4200000, 'active', '2026-01-31 19:29:01', '2026-01-31 19:29:01'),
(4359, 'TAE', 'RKTN', 'Daegu International Airport', NULL, 'KR', 'Gyeongsangnam-do', 35.8969000, 128.6550000, 'active', '2026-01-31 19:29:01', '2026-01-31 19:29:01'),
(4360, 'UJN', 'RKTL', 'Uljin Airport', NULL, 'KR', 'Gyeongsangnam-do', 36.7771000, 129.4620000, 'active', '2026-01-31 19:29:01', '2026-01-31 19:29:01'),
(4361, 'USN', 'RKPU', 'Ulsan Airport', NULL, 'KR', 'Gyeongsangnam-do', 35.5935000, 129.3520000, 'active', '2026-01-31 19:29:02', '2026-01-31 19:29:02'),
(4362, 'YEC', 'RKTY', 'Yecheon Air Base', NULL, 'KR', 'Gyeongsangnam-do', 36.6304000, 128.3500000, 'active', '2026-01-31 19:29:02', '2026-01-31 19:29:02'),
(4363, 'CJU', 'RKPC', 'Jeju International Airport', NULL, 'KR', 'Jeju-teukbyeoljachido', 33.5113000, 126.4930000, 'active', '2026-01-31 19:29:02', '2026-01-31 19:29:02');

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

--
-- Dumping data for table `journal_entries`
--

INSERT INTO `journal_entries` (`id`, `entry_number`, `entry_date`, `reference`, `description`, `total_debit`, `total_credit`, `status`, `created_by`, `created_at`, `updated_at`) VALUES
(6, 'JE-20260203-0001', '2026-02-02', 'm', 'm', 200.00, 200.00, 'posted', 9, '2026-02-02 21:37:48', '2026-02-02 21:37:48'),
(7, 'JE-20260203-0002', '2026-02-02', 'm', 'm', 200.00, 200.00, 'posted', 9, '2026-02-02 21:39:05', '2026-02-02 21:39:05'),
(8, 'JE-20260203-0003', '2026-02-03', 'm', 'Payment for expense: m', 10.00, 10.00, 'posted', 1, '2026-02-02 21:45:39', '2026-02-02 21:45:39'),
(9, 'JE-20260203-0004', '2026-02-03', 'ttf', 'Fueling - RA601 - Open Account - here', 2504.00, 2504.00, 'posted', 9, '2026-02-03 09:36:40', '2026-02-03 09:36:40'),
(10, 'JE-20260203-0005', '2026-02-03', 'ttf', 'Fueling - RA601 - Open Account - here', 2504.00, 2504.00, 'posted', 9, '2026-02-03 09:39:13', '2026-02-03 09:39:13'),
(11, 'JE-20260203-0006', '2026-02-03', 'ttf', 'Fueling - RA601 - Open Account - here', 2504.00, 2504.00, 'posted', 9, '2026-02-03 09:39:40', '2026-02-03 09:39:40'),
(12, 'JE-20260203-0007', '2026-02-03', 's23', 'Fueling - RA601 - Open Account - heres', 104.00, 104.00, 'posted', 9, '2026-02-03 10:07:46', '2026-02-03 10:07:46'),
(13, 'JE-20260203-0008', '2026-02-03', 'uuy', 'Fueling - RA202 - Open Account - nairobi', 1010.00, 1010.00, 'posted', 9, '2026-02-03 10:18:25', '2026-02-03 10:18:25'),
(14, 'JE-20260204-0001', '2026-02-04', '112', 'test1', 50.00, 50.00, 'posted', 9, '2026-02-04 04:44:14', '2026-02-04 04:44:14'),
(15, 'JE-20260204-0002', '2026-02-04', '112', 'Payment for expense: test1', 50.00, 50.00, 'posted', 1, '2026-02-04 04:44:57', '2026-02-04 04:44:57'),
(16, 'JE-20260204-0003', '2026-02-04', '223', 'test2', 40.00, 40.00, 'posted', 9, '2026-02-04 04:46:07', '2026-02-04 04:46:07'),
(17, 'JE-20260204-0004', '2026-02-04', 'tee', 'internt', 5.00, 5.00, 'posted', 9, '2026-02-04 04:49:03', '2026-02-04 04:49:03'),
(18, 'JE-20260223-0001', '2026-02-23', 'BKMLYWX2BL62FD', 'Booking revenue - FLIGHT006', 400.00, 400.00, 'posted', 1, '2026-02-23 08:26:19', '2026-02-23 08:26:19'),
(19, 'JE-20260223-0002', '2026-02-23', 'BKMLYX61YPZ9PV', 'Booking revenue - FLIGHT006', 400.00, 400.00, 'posted', 1, '2026-02-23 08:33:18', '2026-02-23 08:33:18'),
(20, 'JE-20260223-0003', '2026-02-23', 'BKMLYY8SXPF3K1', 'Booking revenue - FLIGHT006', 400.00, 400.00, 'posted', 1, '2026-02-23 09:03:26', '2026-02-23 09:03:26'),
(21, 'JE-20260223-0004', '2026-02-23', 'BKMLZ0IJQXAKRG', 'Booking revenue - FLIGHT006', 400.00, 400.00, 'posted', 1, '2026-02-23 10:07:00', '2026-02-23 10:07:00');

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

--
-- Dumping data for table `journal_entry_lines`
--

INSERT INTO `journal_entry_lines` (`id`, `journal_entry_id`, `account_id`, `debit_amount`, `credit_amount`, `description`) VALUES
(11, 6, 98, 200.00, 0.00, 'm'),
(12, 6, 30, 0.00, 200.00, 'Accounts Payable: m'),
(13, 7, 98, 200.00, 0.00, 'm'),
(14, 7, 30, 0.00, 200.00, 'Accounts Payable: m'),
(15, 8, 30, 10.00, 0.00, 'Payment reducing accounts payable'),
(16, 8, 26, 0.00, 10.00, 'Payment via ABSA'),
(17, 9, 98, 2504.00, 0.00, 'Fueling - RA601 - 50L @ 50/L'),
(18, 9, 30, 0.00, 2504.00, 'Fueling payable to Open Account - Slip: ttf'),
(19, 10, 98, 2504.00, 0.00, 'Fueling - RA601 - 50L @ 50/L'),
(20, 10, 30, 0.00, 2504.00, 'Fueling payable to Open Account - Slip: ttf'),
(21, 11, 98, 2504.00, 0.00, 'Fueling - RA601 - 50L @ 50/L'),
(22, 11, 30, 0.00, 2504.00, 'Fueling payable to Open Account - Slip: ttf'),
(23, 12, 98, 92.00, 0.00, 'Fueling - RA601 - 30L @ 3/L'),
(24, 12, 16, 12.00, 0.00, 'Purchase Tax - Fueling - RA601 - Slip: s23'),
(25, 12, 30, 0.00, 92.00, 'Fueling payable to Open Account - Slip: s23'),
(26, 12, 32, 0.00, 12.00, 'Tax liability - Fueling - RA601 - Slip: s23'),
(27, 13, 98, 1005.00, 0.00, 'Fueling - RA202 - 100L @ 10/L'),
(28, 13, 16, 5.00, 0.00, 'Purchase Tax - Fueling - RA202 - Slip: uuy'),
(29, 13, 30, 0.00, 1005.00, 'Fueling payable to Open Account - Slip: uuy'),
(30, 13, 32, 0.00, 5.00, 'Tax liability - Fueling - RA202 - Slip: uuy'),
(31, 14, 96, 50.00, 0.00, 'test1'),
(32, 14, 30, 0.00, 50.00, 'Accounts Payable: test1'),
(33, 15, 30, 50.00, 0.00, 'Payment reducing accounts payable'),
(34, 15, 24, 0.00, 50.00, 'Payment via Cash'),
(35, 16, 84, 40.00, 0.00, 'test2'),
(36, 16, 21, 0.00, 40.00, 'Payment via DTB KES'),
(37, 17, 103, 5.00, 0.00, 'internt'),
(38, 17, 30, 0.00, 5.00, 'Accounts Payable: internt'),
(39, 18, 3, 400.00, 0.00, 'Booking revenue - FLIGHT006 - BKMLYWX2BL62FD'),
(40, 18, 26, 0.00, 400.00, 'Payment received via ABSA - BKMLYWX2BL62FD'),
(41, 19, 53, 400.00, 0.00, 'Booking revenue - FLIGHT006 - BKMLYX61YPZ9PV'),
(42, 19, 28, 0.00, 400.00, 'Payment received via ABSA-USD - BKMLYX61YPZ9PV'),
(43, 20, 3, 400.00, 0.00, 'Booking revenue - FLIGHT006 - BKMLYY8SXPF3K1'),
(44, 20, 23, 0.00, 400.00, 'Payment received via M-pesa - BKMLYY8SXPF3K1'),
(45, 21, 3, 400.00, 0.00, 'Booking revenue - FLIGHT006 - BKMLZ0IJQXAKRG'),
(46, 21, 26, 0.00, 400.00, 'Payment received via ABSA - BKMLZ0IJQXAKRG');

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

--
-- Dumping data for table `loyalty_tiers`
--

INSERT INTO `loyalty_tiers` (`id`, `name`, `min_points`, `description`, `created_at`) VALUES
(1, 'BRONZE', 0, 'Entry level member benefits', '2026-01-08 10:21:05'),
(2, 'SILVER', 2001, 'Silver level member benefits with priority check-in', '2026-01-08 10:21:05'),
(3, 'GOLD', 5001, 'Gold level member benefits with lounge access', '2026-01-08 10:21:05'),
(4, 'PLATINUM', 10001, 'Premium level member benefits with all perks', '2026-01-08 10:21:05');

-- --------------------------------------------------------

--
-- Table structure for table `luggage`
--

CREATE TABLE `luggage` (
  `id` int(11) NOT NULL,
  `passenger_id` int(11) NOT NULL,
  `flight_series_id` int(11) DEFAULT NULL,
  `booking_id` int(11) DEFAULT NULL,
  `tag_number` varchar(50) DEFAULT NULL,
  `weight` decimal(8,2) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `luggage`
--

INSERT INTO `luggage` (`id`, `passenger_id`, `flight_series_id`, `booking_id`, `tag_number`, `weight`, `created_at`, `updated_at`) VALUES
(1, 19, 3, 6, '2', 3.00, '2025-12-05 09:49:04', '2025-12-05 10:13:45'),
(4, 19, 3, 6, '3', 3.00, '2025-12-05 10:13:45', '2025-12-05 10:13:45'),
(5, 27, 6, 16, 'AA0011', 30.00, '2025-12-06 11:08:09', '2025-12-06 11:08:09'),
(6, 50, 23, 39, '4556', 5.00, '2026-02-22 20:16:38', '2026-02-22 20:16:38');

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

--
-- Dumping data for table `notices`
--

INSERT INTO `notices` (`id`, `title`, `content`, `country_id`, `created_at`, `status`) VALUES
(13, 'Ticket Prices', 'Price drop for all tickets', 3, '2025-11-18 08:53:03', 1);

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

--
-- Dumping data for table `offers`
--

INSERT INTO `offers` (`id`, `title`, `description`, `image_url`, `promo_code`, `expiry_date`, `is_active`, `created_at`) VALUES
(1, 'Launch Offer', 'Get 20% off your first booking', NULL, 'ROYAL20', NULL, 1, '2026-01-08 11:25:40'),
(2, 'Weekend Getaway', 'Fly to Mombasa this weekend for less', NULL, 'BEACHVIBES', NULL, 1, '2026-01-08 11:25:40');

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
  `identification` varchar(100) DEFAULT NULL,
  `age` int(11) DEFAULT NULL,
  `title` varchar(20) DEFAULT NULL,
  `booking_status` varchar(50) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `passengers`
--

INSERT INTO `passengers` (`id`, `pnr`, `name`, `email`, `contact`, `nationality`, `identification`, `age`, `title`, `booking_status`, `created_at`, `updated_at`) VALUES
(1, '1VFDQ5QWNO', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', 'kenyan', '12345678', 21, 'Mr.', NULL, '2025-11-30 07:33:53', '2025-11-30 07:33:53'),
(2, 'YQZNJ9J0PQ', 'br', 'bryanotieno09@gmail.com', '34', NULL, NULL, NULL, NULL, NULL, '2025-12-01 17:44:51', '2025-12-01 17:44:51'),
(3, 'MR9KB897S3', 's', 'bryanotieno09s@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-01 17:44:51', '2025-12-01 17:44:51'),
(4, 'NYX0M4D19C', 's', 'bryanotieno09@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, '2025-12-01 17:44:52', '2025-12-01 17:44:52'),
(5, '3X7O893G5G', 'br', 'bryanotieno09@gmail.com', '34', NULL, NULL, NULL, 'Mr', NULL, '2025-12-01 20:22:11', '2025-12-01 20:22:11'),
(6, 'DXBWZBWOEV', 'f', 'bryanotieno09@gmail.com', 'g', '4', NULL, NULL, 'Mrs', NULL, '2025-12-01 20:22:11', '2025-12-01 20:22:11'),
(7, 'JA3L147CPJ', 'f', 'bryanotieno093@gmail.com', '4', 'd', NULL, 5, 'Mrs', NULL, '2025-12-01 20:22:11', '2025-12-01 20:22:11'),
(8, 'QPABUUKOLB', 'br', 'bryanotieno09@gmail.com', '34', NULL, NULL, NULL, 'Mr', NULL, '2025-12-01 20:24:47', '2025-12-01 20:24:47'),
(9, 'EP8YHR1LUJ', 'f', 'bryanotieno09@gmail.com', 'g', '4', NULL, NULL, 'Mrs', NULL, '2025-12-01 20:24:48', '2025-12-01 20:24:48'),
(10, '9OWCLZ7M6P', 'f', 'bryanotieno093@gmail.com', '4', 'd', NULL, 5, 'Mrs', NULL, '2025-12-01 20:24:48', '2025-12-01 20:24:48'),
(11, '7O5BVHLHL3', 'br', 'bryanotieno09@gmail.com', '34', NULL, NULL, NULL, 'Mr', NULL, '2025-12-01 20:28:57', '2025-12-01 20:28:57'),
(12, 'XBTG4E02DK', 'd', 'bryanotieno09s@gmail.com', 'd', NULL, '3', 3, 'Mrs', NULL, '2025-12-01 20:28:58', '2025-12-01 20:28:58'),
(13, 'WB4WJ28RFT', '3', 'bryanotieno019@gmail.com', '3', 'e', NULL, NULL, 'Miss', NULL, '2025-12-01 20:28:58', '2025-12-01 20:28:58'),
(14, 'QSU245K4UL', 'br', 'bryanotieno09@gmail.com', '34', NULL, NULL, NULL, NULL, 'Boarded', '2025-12-01 20:33:46', '2025-12-03 13:59:26'),
(15, '33J9Y9BYJ2', 'v', 'bryanotieno059@gmail.com', '5', NULL, NULL, NULL, 'Mr', 'Boarded', '2025-12-01 20:33:46', '2025-12-04 12:35:09'),
(16, 'V4N83WYMUJ', 'g', 'bryanotieno0679@gmail.com', 'g', NULL, NULL, NULL, 'Mrs', 'Boarded', '2025-12-01 20:33:46', '2025-12-04 12:35:13'),
(17, 'LH5FVDAV3B', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', NULL, NULL, NULL, NULL, 'CHECK IN', '2025-12-01 20:38:16', '2025-12-05 09:28:13'),
(18, 'QNECY42W91', 'br', 'bryanotieno09@gmail.com', '34', NULL, NULL, NULL, NULL, NULL, '2025-12-01 20:46:48', '2025-12-01 20:46:48'),
(19, 'XYLWPMFVQA', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', NULL, NULL, 30, 'Mr', 'CHECK IN', '2025-12-04 13:20:01', '2025-12-05 09:09:44'),
(20, 'AYUWHA8P2B', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK12345', 0, 'Mr', NULL, '2025-12-05 11:33:00', '2025-12-05 11:33:00'),
(21, 'VJEDEWUR5Z', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK00000', 0, 'Mr', NULL, '2025-12-05 11:43:26', '2025-12-05 11:43:26'),
(22, '4YPJR3ONN7', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Comoros', '123455', 30, NULL, NULL, '2025-12-05 13:12:57', '2025-12-05 13:12:57'),
(23, 'KXUQ2F80QT', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Comoros', '123455', 30, NULL, NULL, '2025-12-05 13:15:32', '2025-12-05 13:15:32'),
(24, '1QGL6R2VJM', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'comoros', '33', 3, NULL, NULL, '2025-12-05 13:34:33', '2025-12-05 13:34:33'),
(25, 'P9QMLEYHN7', 'Mr John Doe', 'john.doe@example.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2025-12-05 13:42:28', '2025-12-05 13:42:28'),
(26, 'NE0YJXW2QH', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'k', NULL, 79, 'Mr', NULL, '2025-12-05 13:46:36', '2025-12-05 15:10:11'),
(27, 'BT9K1YB9UL', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', NULL, 35, NULL, 'Boarded', '2025-12-06 11:07:42', '2025-12-06 11:08:19'),
(28, 'SGJM4ZDZJD', 'Mr John’s Doe', 'john.doe@example.com', '0706166875', 'Kenya', 'Gkalllllll', 0, 'Mr', NULL, '2025-12-07 11:08:19', '2025-12-07 11:08:19'),
(29, '2Q6TT32KH4', 'Mr Benjamin  Okwama', '', '', 'Mauritian', 'Mk0001', 0, 'Mr', NULL, '2025-12-07 11:21:24', '2025-12-07 11:21:24'),
(30, 'NP6WH9X36L', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-10 12:03:26', '2025-12-10 12:03:26'),
(31, 'GKVLZPPJ34', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-10 12:31:31', '2025-12-10 12:31:31'),
(32, 'HPY3QR6P2W', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-10 12:31:33', '2025-12-10 12:31:33'),
(33, 'BQRNXDU8J9', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-10 14:25:35', '2025-12-10 14:25:35'),
(34, 'B23BTULA7K', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-10 14:39:43', '2025-12-10 14:39:43'),
(35, 'W6LR9G9SJY', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-10 15:02:51', '2025-12-10 15:02:51'),
(36, 'RYBQ9UULVN', 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-10 15:03:17', '2025-12-10 15:03:17'),
(37, '4RPRDD5X4Y', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-11 16:21:44', '2025-12-11 16:21:44'),
(38, 'U74TCYJ73G', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2025-12-11 16:21:57', '2025-12-11 16:21:57'),
(39, '8NVVXYU9VX', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2026-01-27 11:28:16', '2026-01-27 11:28:16'),
(40, 'A27NWZGT3Q', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2026-01-27 11:30:09', '2026-01-27 11:30:09'),
(41, '8NZCEN7AXB', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2026-01-27 11:30:12', '2026-01-27 11:30:12'),
(42, '74AAWS7GKC', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2026-01-27 11:30:13', '2026-01-27 11:30:13'),
(43, '64BCGN2N5A', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2026-01-27 11:30:14', '2026-01-27 11:30:14'),
(44, 'EVNAMQLNHN', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', 'Boarded', '2026-01-27 11:30:22', '2026-01-30 20:31:36'),
(45, 'H8AAUGQKRC', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', 'Boarded', '2026-01-27 11:31:43', '2026-01-30 20:31:27'),
(46, 'E2EKTMABYM', 'Mr Benjamin Okwama', 'john.doe@example.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', 'Boarded', '2026-01-27 12:40:58', '2026-01-30 20:33:21'),
(47, 'RUHVJVMGJU', 'Mr Benjamin Okwama', 'reviewer@mcaviation.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', 'Boarded', '2026-01-31 16:00:54', '2026-02-01 04:39:17'),
(48, 'CFX8UJXAU5', 'Mr Benjamin Okwama', 'reviewer@mcaviation.com', '0706166875', 'Kenyan', 'BK908881', 28, 'Mr', NULL, '2026-02-11 13:39:06', '2026-02-11 13:39:06'),
(49, 'F11MNWLNB3', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-21 19:15:45', '2026-02-21 19:15:45'),
(50, 'CHQI161RQ5', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'kenyan', '4444444', 37, NULL, 'Boarded', '2026-02-22 20:09:43', '2026-02-22 20:10:50'),
(51, 'M7QVMSRUG4', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'Kenyan', NULL, 30, NULL, NULL, '2026-02-23 07:45:44', '2026-02-23 07:45:44'),
(52, '7OL74RHZE5', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 07:50:26', '2026-02-23 07:50:26'),
(53, 'YDXF23PK8R', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 07:53:13', '2026-02-23 07:53:13'),
(54, 'I71NGU6M80', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'n', NULL, 60, NULL, NULL, '2026-02-23 07:56:06', '2026-02-23 07:56:06'),
(55, 'EH4SG7MA6W', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 07:59:19', '2026-02-23 07:59:19'),
(56, 'IGETG722FL', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 08:00:18', '2026-02-23 08:00:18'),
(57, 'S9TUX9MVI1', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 08:03:20', '2026-02-23 08:03:20'),
(58, 'TGIWVBCU1U', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'Kenya', NULL, NULL, NULL, NULL, '2026-02-23 08:24:13', '2026-02-23 08:24:13'),
(59, 'TQHVFDVCKI', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 08:26:18', '2026-02-23 08:26:18'),
(60, '70LMNR4EQV', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 08:33:17', '2026-02-23 08:33:17'),
(61, 'N4CVJEA99R', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'ff', NULL, NULL, NULL, NULL, '2026-02-23 09:03:25', '2026-02-23 09:03:25'),
(62, 'NDZMCMT6K6', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:12:52', '2026-02-23 09:12:52'),
(63, 'R2BR5H8W95', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:14:08', '2026-02-23 09:14:08'),
(64, '6S31SNXZ5P', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:15:20', '2026-02-23 09:15:20'),
(65, 'LCS2LBY0GO', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:20:19', '2026-02-23 09:20:19'),
(66, '0DW3XAA90C', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, 'Mr', NULL, '2026-02-23 09:21:19', '2026-02-23 09:21:19'),
(67, 'E5ON8TOG8Q', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:26:16', '2026-02-23 09:26:16'),
(68, '1AC01U1Y6J', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'dd', NULL, NULL, NULL, NULL, '2026-02-23 09:27:20', '2026-02-23 09:27:20'),
(69, 'TGR7HQQR42', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:33:07', '2026-02-23 09:33:07'),
(70, '9JLH8NYFZR', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:37:52', '2026-02-23 09:37:52'),
(71, 'V9WV5O1506', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:37:56', '2026-02-23 09:37:56'),
(72, 'PTGKKRUN3K', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:39:56', '2026-02-23 09:39:56'),
(73, 'UWHCA4VJCC', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:44:50', '2026-02-23 09:44:50'),
(74, 'ED2RR45VS9', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:45:15', '2026-02-23 09:45:15'),
(75, 'B5AIBCIHIF', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:50:03', '2026-02-23 09:50:03'),
(76, 'SWZUI0DMEI', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 09:59:36', '2026-02-23 09:59:36'),
(77, 'RJVIE25OGJ', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', NULL, NULL, NULL, NULL, NULL, '2026-02-23 10:02:53', '2026-02-23 10:02:53'),
(78, 'FCG02CG13K', 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'dd', NULL, NULL, NULL, NULL, '2026-02-23 10:06:59', '2026-02-23 10:06:59'),
(79, '64XLLVJD6A', 'Benjamin Okwama', 'reviewer@mcaviation.com', '0706166875', 'Kenyan ', 'BK34011563', NULL, NULL, NULL, '2026-02-24 12:43:53', '2026-02-24 12:43:53'),
(80, 'JZCCUD263Y', 'Benjamin Okwama', 'reviewer@mcaviation.com', '0706166875', 'Kenyan', 'BK34011563', NULL, NULL, NULL, '2026-02-24 13:36:17', '2026-02-24 13:36:17'),
(81, '9988417640374', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Japanese', 'PD3456798', NULL, NULL, NULL, '2026-02-25 11:12:09', '2026-02-25 11:12:09'),
(82, '9986878827837', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Nairobi', '1244', NULL, NULL, NULL, '2026-02-26 13:03:00', '2026-02-26 13:03:00'),
(83, '9984402423882', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Nairobi', '1244', NULL, NULL, NULL, '2026-02-26 13:03:23', '2026-02-26 13:03:23'),
(84, '9986677047806', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Kenya', '124455888', NULL, NULL, NULL, '2026-02-26 18:13:02', '2026-02-26 18:13:02'),
(85, '9987850770192', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'UK', 'KOKIUYTR', NULL, 'Mr', NULL, '2026-02-26 18:41:15', '2026-02-26 18:41:15'),
(86, '9983801199212', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Japanese ', 'JK088665', NULL, NULL, NULL, '2026-02-27 09:58:58', '2026-02-27 09:58:58'),
(87, '9985832677200', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Japanese ', 'JK088665', NULL, NULL, NULL, '2026-02-27 09:59:02', '2026-02-27 09:59:02'),
(88, '9989283183251', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Japanese ', 'JK088665', NULL, NULL, NULL, '2026-02-27 09:59:04', '2026-02-27 09:59:04'),
(89, '9981869059876', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'JAPANESE ', 'JK688999', NULL, NULL, NULL, '2026-02-27 10:08:42', '2026-02-27 10:08:42'),
(90, '9980485502098', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Ugandan ', 'UGX64846488', NULL, 'Mr', NULL, '2026-02-27 10:21:15', '2026-02-27 10:21:15'),
(91, '9988730952311', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Ugandan ', 'UGX64846488', NULL, 'Mr', NULL, '2026-02-27 10:30:52', '2026-02-27 10:30:52'),
(92, '9982963706061', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Ugcx', 'ASREWQ', NULL, 'Mr', NULL, '2026-02-27 10:51:56', '2026-02-27 10:51:56'),
(93, '9981322953467', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Ugcx', 'ASREWQ', NULL, 'Mr', NULL, '2026-02-27 10:53:13', '2026-02-27 10:53:13'),
(94, '9984784076312', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Hu', 'SD45666', NULL, NULL, NULL, '2026-02-27 11:11:50', '2026-02-27 11:11:50'),
(95, '9988028964600', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'Hu', 'SD45666', NULL, NULL, NULL, '2026-02-27 11:15:36', '2026-02-27 11:15:36'),
(96, '9983546392217', 'Benjamin Okwama', 'bennjiokwama@gmail.com', '0706166875', 'ASDYY', '456677787', NULL, 'Mr', NULL, '2026-02-27 13:20:55', '2026-02-27 13:20:55');

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
  `user_id` int(11) NOT NULL,
  `amount` decimal(10,2) NOT NULL,
  `currency` varchar(3) DEFAULT 'KES',
  `payment_method` varchar(50) NOT NULL COMMENT 'M-Pesa, Card, etc',
  `payment_reference` varchar(100) DEFAULT NULL,
  `transaction_id` varchar(100) DEFAULT NULL COMMENT 'External payment gateway ID',
  `status` enum('pending','completed','failed','refunded') DEFAULT 'pending',
  `payment_date` datetime DEFAULT NULL,
  `metadata` text DEFAULT NULL COMMENT 'JSON data from payment gateway',
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `payment_transactions`
--

INSERT INTO `payment_transactions` (`id`, `booking_id`, `user_id`, `amount`, `currency`, `payment_method`, `payment_reference`, `transaction_id`, `status`, `payment_date`, `metadata`, `created_at`, `updated_at`) VALUES
(1, 84, 1, 119003.94, 'KES', 'M-Pesa', 'CZKMOU', 'ws_CO_27022026162107806706166875', 'failed', '2026-02-27 16:21:16', '{\"merchant_request_id\":\"b812-4789-a1aa-8172e88dc13313646\",\"checkout_request_id\":\"ws_CO_27022026162107806706166875\",\"result_code\":1032,\"result_desc\":\"Request Cancelled by user.\",\"booking_reference\":null,\"status\":\"failed\"}', '2026-02-27 13:21:07', '2026-02-27 13:21:16');

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
-- Table structure for table `seat_reservations`
--

CREATE TABLE `seat_reservations` (
  `id` int(11) NOT NULL,
  `flight_series_id` int(11) NOT NULL,
  `number_of_seats` int(11) NOT NULL DEFAULT 1,
  `passenger_id` int(11) NOT NULL,
  `passenger_name` varchar(255) NOT NULL,
  `passenger_email` varchar(255) DEFAULT NULL,
  `passenger_phone` varchar(50) DEFAULT NULL,
  `booking_reference` varchar(50) NOT NULL,
  `status` varchar(50) NOT NULL DEFAULT 'reserved',
  `reservation_date` date NOT NULL,
  `notes` text DEFAULT NULL,
  `agent_id` int(11) DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  `updated_at` timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Dumping data for table `seat_reservations`
--

INSERT INTO `seat_reservations` (`id`, `flight_series_id`, `number_of_seats`, `passenger_id`, `passenger_name`, `passenger_email`, `passenger_phone`, `booking_reference`, `status`, `reservation_date`, `notes`, `agent_id`, `created_at`, `updated_at`) VALUES
(1, 1, 1, 0, 'br', 'bryanotieno09@gmail.com', '34', 'U164P1', 'reserved', '2025-11-30', 'noting', NULL, '2025-11-30 06:17:30', '2025-11-30 06:17:30'),
(2, 2, 1, 0, 'br', 'bryanotieno09@gmail.com', '34', '1HBTSO', 'booked', '2025-12-01', NULL, NULL, '2025-11-30 06:25:31', '2025-12-01 20:46:50'),
(3, 1, 3, 0, 'br', 'bryanotieno09@gmail.com', '34', 'M2QJSE', 'reserved', '2025-12-02', NULL, NULL, '2025-11-30 06:26:14', '2025-11-30 06:26:14'),
(4, 2, 1, 0, 'br', 'bryanotieno039@gmail.com', '343', 'TN0QVZ', 'reserved', '2025-11-27', 'dd', NULL, '2025-11-30 07:44:51', '2025-11-30 07:44:51'),
(5, 1, 1, 0, 'jane', 'br9@gmail.com', '555', '1LBUEE', 'reserved', '2025-11-30', NULL, NULL, '2025-11-30 07:57:13', '2025-11-30 07:57:13'),
(6, 1, 1, 1, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', 'Y2E9W7', 'booked', '2025-12-01', 'test', NULL, '2025-12-01 16:50:10', '2025-12-01 20:38:17'),
(7, 2, 1, 17, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', '2WHYQM', 'reserved', '2025-12-01', 'n', NULL, '2025-12-01 20:45:20', '2025-12-01 20:45:20'),
(8, 3, 1, 17, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0790193625', 'H444PP', 'booked', '2025-12-04', 'test', NULL, '2025-12-04 13:18:53', '2025-12-04 13:20:02'),
(9, 4, 1, 21, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'Y4DS0T', 'booked', '2025-12-05', 'more', 1, '2025-12-05 13:00:41', '2025-12-05 13:46:39'),
(10, 6, 1, 26, 'Mr John Doe', 'john.doe@example.com', '0706166875', 'YN7PM5', 'booked', '2025-12-06', NULL, 1, '2025-12-06 11:07:08', '2025-12-06 11:07:45'),
(11, 23, 1, 49, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'MJD616', 'checked_in', '2026-02-21', 'nn', NULL, '2026-02-21 19:15:45', '2026-02-22 20:10:01'),
(12, 24, 1, 50, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'JP6YE1', 'booked', '2026-02-23', 'testing', NULL, '2026-02-23 07:20:55', '2026-02-23 07:56:07'),
(13, 24, 1, 53, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'HD7DU8', 'booked', '2026-02-23', NULL, NULL, '2026-02-23 07:58:55', '2026-02-23 10:07:01'),
(14, 24, 1, 66, 'BRYAN OTIENO ONYANGO', 'bryanotieno09@gmail.com', '0706166875', 'MJYEYA', 'booked', '2026-02-23', NULL, NULL, '2026-02-23 09:27:05', '2026-02-23 09:45:17');

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

--
-- Dumping data for table `staff`
--

INSERT INTO `staff` (`id`, `name`, `photo_url`, `empl_no`, `id_no`, `role`, `designation`, `phone_number`, `password`, `department`, `department_id`, `manager_id`, `business_email`, `department_email`, `salary`, `employment_type`, `gender`, `created_at`, `updated_at`, `is_active`, `avatar_url`, `status`, `my_password`, `wifi_ip`, `shift`, `offer_date`, `start_date`, `date_of_birth`, `marital_status`, `nationality`, `address`, `nhif_number`, `nssf_number`, `kra_pin`, `passport_number`, `bank_name`, `bank_branch`, `account_number`, `account_name`, `swift_code`, `benefits`) VALUES
(9, 'admins', 'https://res.cloudinary.com/otienobryan/image/upload/v1757252591/uploads/wsxidqwfmgy8ib5tic1m.jpg', '123355', '9', 'executive', 'Staff Member', '55', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', 'Executive', 3, NULL, 'admin@royal.com', 'admin@royal.com', 40000.00, 'Permanent', 'Male', '2025-07-19 12:38:19', '2025-11-28 13:09:35', 1, '', 1, '', '', 0, NULL, NULL, NULL, NULL, NULL, NULL, 'jjj', NULL, NULL, NULL, 'nnmm', 'nn', 'nn', NULL, NULL, NULL),
(20, 's', 'https://res.cloudinary.com/otienobryan/image/upload/v1764762270/staff/mslbalzdvw4uznscynol.jpg', '2', '3', 's', '', '0790193625', 's', 'Finance', 2, NULL, 'bryanotieno09@gmail.com', 'bryanotieno09@gmail.com', 0.00, 'Contract', 'Male', '2025-12-03 11:44:31', '2025-12-06 07:14:21', 1, 'https://res.cloudinary.com/otienobryan/image/upload/v1764762270/staff/mslbalzdvw4uznscynol.jpg', 1, '', '', 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL),
(21, 'test', 'https://res.cloudinary.com/otienobryan/image/upload/v1765005297/staff/plpal99p6ayv4juqbclt.png', 't', '44', '', '', '', '$2a$10$me0dzhAfGglEGPhcK/34BuWmhYW3USYy3SeMbe46CQop102Yq./1S', 'Reservations', 3, NULL, '', '', 3000.00, 'Contract', 'Male', '2025-12-03 11:54:48', '2026-02-04 05:35:41', 1, 'https://res.cloudinary.com/otienobryan/image/upload/v1765005297/staff/plpal99p6ayv4juqbclt.png', 1, '', '', 0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL);

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

--
-- Dumping data for table `suppliers`
--

INSERT INTO `suppliers` (`id`, `supplier_code`, `company_name`, `contact_person`, `email`, `phone`, `address`, `tax_id`, `payment_terms`, `credit_limit`, `is_active`, `created_at`, `updated_at`) VALUES
(1, 'we', 'Open Account', '', '', '3455', '', '', 0, 0.00, 1, '2025-09-10 18:52:39', '2026-02-02 05:01:46');

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

--
-- Dumping data for table `supplier_ledger`
--

INSERT INTO `supplier_ledger` (`id`, `supplier_id`, `date`, `description`, `reference_type`, `reference_id`, `debit`, `credit`, `running_balance`, `created_at`) VALUES
(1, 1, '2026-02-03 03:00:00', 'Fueling - RA601 - Slip: ttf', 'FUELING', NULL, 0.00, 2504.00, 2504.00, '2026-02-03 09:39:14'),
(2, 1, '2026-02-03 03:00:00', 'Fueling - RA601 - Slip: ttf', 'FUELING', 1, 0.00, 2504.00, 5008.00, '2026-02-03 09:39:41'),
(3, 1, '2026-02-03 03:00:00', 'Fueling - RA601 - Slip: s23', 'FUELING', 2, 0.00, 104.00, 5112.00, '2026-02-03 10:07:48'),
(4, 1, '2026-02-03 03:00:00', 'Fueling - RA202 - Slip: uuy', 'FUELING', 3, 0.00, 1010.00, 6122.00, '2026-02-03 10:18:26');

--
-- Indexes for dumped tables
--

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
  ADD KEY `idx_transaction_date` (`transaction_date`);

--
-- Indexes for table `agents`
--
ALTER TABLE `agents`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_agency_id` (`agency_id`),
  ADD KEY `idx_name` (`name`),
  ADD KEY `idx_email` (`email`);

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
  ADD KEY `idx_status` (`status`);

--
-- Indexes for table `booking_passengers`
--
ALTER TABLE `booking_passengers`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_booking_passenger` (`booking_id`,`passenger_id`),
  ADD KEY `passenger_id` (`passenger_id`);

--
-- Indexes for table `cabin_classes`
--
ALTER TABLE `cabin_classes`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_name` (`name`);

--
-- Indexes for table `cargo_bookings`
--
ALTER TABLE `cargo_bookings`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `awb_number` (`awb_number`),
  ADD KEY `flight_series_id` (`flight_series_id`),
  ADD KEY `idx_awb_number` (`awb_number`),
  ADD KEY `idx_cargo_booking_date` (`booking_date`);

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
-- Indexes for table `experiences`
--
ALTER TABLE `experiences`
  ADD PRIMARY KEY (`id`);

--
-- Indexes for table `flight_crew`
--
ALTER TABLE `flight_crew`
  ADD PRIMARY KEY (`id`),
  ADD UNIQUE KEY `unique_flight_crew` (`flight_series_id`,`crew_id`),
  ADD KEY `idx_flight_series_id` (`flight_series_id`),
  ADD KEY `idx_crew_id` (`crew_id`);

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
  ADD KEY `idx_booking` (`booking_id`),
  ADD KEY `idx_user` (`user_id`),
  ADD KEY `idx_status` (`status`),
  ADD KEY `idx_reference` (`payment_reference`);

--
-- Indexes for table `payroll`
--
ALTER TABLE `payroll`
  ADD PRIMARY KEY (`id`),
  ADD KEY `idx_journal_entry_id` (`journal_entry_id`),
  ADD KEY `idx_staff_id` (`staff_id`),
  ADD KEY `idx_payroll_date` (`payroll_date`);

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
  ADD KEY `idx_agent_id` (`agent_id`);

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
-- AUTO_INCREMENT for dumped tables
--

--
-- AUTO_INCREMENT for table `account_category`
--
ALTER TABLE `account_category`
  MODIFY `id` int(3) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=6;

--
-- AUTO_INCREMENT for table `account_deletion_requests`
--
ALTER TABLE `account_deletion_requests`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `account_types`
--
ALTER TABLE `account_types`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `agencies`
--
ALTER TABLE `agencies`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `agency_deposits`
--
ALTER TABLE `agency_deposits`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `agency_ledger`
--
ALTER TABLE `agency_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=24;

--
-- AUTO_INCREMENT for table `agents`
--
ALTER TABLE `agents`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `aircrafts`
--
ALTER TABLE `aircrafts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=9;

--
-- AUTO_INCREMENT for table `airline_users`
--
ALTER TABLE `airline_users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `bookings`
--
ALTER TABLE `bookings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=85;

--
-- AUTO_INCREMENT for table `booking_passengers`
--
ALTER TABLE `booking_passengers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=82;

--
-- AUTO_INCREMENT for table `cabin_classes`
--
ALTER TABLE `cabin_classes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `cargo_bookings`
--
ALTER TABLE `cargo_bookings`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `Category`
--
ALTER TABLE `Category`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=20;

--
-- AUTO_INCREMENT for table `chart_of_accounts`
--
ALTER TABLE `chart_of_accounts`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=145;

--
-- AUTO_INCREMENT for table `chat_messages`
--
ALTER TABLE `chat_messages`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=150;

--
-- AUTO_INCREMENT for table `chat_rooms`
--
ALTER TABLE `chat_rooms`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=50;

--
-- AUTO_INCREMENT for table `chat_room_members`
--
ALTER TABLE `chat_room_members`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=124;

--
-- AUTO_INCREMENT for table `Country`
--
ALTER TABLE `Country`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `crew`
--
ALTER TABLE `crew`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `delete_acc`
--
ALTER TABLE `delete_acc`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `departments`
--
ALTER TABLE `departments`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=11;

--
-- AUTO_INCREMENT for table `destinations`
--
ALTER TABLE `destinations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=35;

--
-- AUTO_INCREMENT for table `device_tokens`
--
ALTER TABLE `device_tokens`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=44;

--
-- AUTO_INCREMENT for table `exchange_rates`
--
ALTER TABLE `exchange_rates`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=58;

--
-- AUTO_INCREMENT for table `expenses`
--
ALTER TABLE `expenses`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=8;

--
-- AUTO_INCREMENT for table `experiences`
--
ALTER TABLE `experiences`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `flight_crew`
--
ALTER TABLE `flight_crew`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `flight_series`
--
ALTER TABLE `flight_series`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=26;

--
-- AUTO_INCREMENT for table `fueling`
--
ALTER TABLE `fueling`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4;

--
-- AUTO_INCREMENT for table `hotels`
--
ALTER TABLE `hotels`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `iata_codes`
--
ALTER TABLE `iata_codes`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=4364;

--
-- AUTO_INCREMENT for table `journal_entries`
--
ALTER TABLE `journal_entries`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `journal_entry_lines`
--
ALTER TABLE `journal_entry_lines`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=47;

--
-- AUTO_INCREMENT for table `loyalty_points_history`
--
ALTER TABLE `loyalty_points_history`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `loyalty_tiers`
--
ALTER TABLE `loyalty_tiers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- AUTO_INCREMENT for table `luggage`
--
ALTER TABLE `luggage`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT for table `notices`
--
ALTER TABLE `notices`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=14;

--
-- AUTO_INCREMENT for table `notifications`
--
ALTER TABLE `notifications`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `offers`
--
ALTER TABLE `offers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=3;

--
-- AUTO_INCREMENT for table `passengers`
--
ALTER TABLE `passengers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=97;

--
-- AUTO_INCREMENT for table `password_resets`
--
ALTER TABLE `password_resets`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `payment_transactions`
--
ALTER TABLE `payment_transactions`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `payroll`
--
ALTER TABLE `payroll`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT for table `seat_reservations`
--
ALTER TABLE `seat_reservations`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=15;

--
-- AUTO_INCREMENT for table `staff`
--
ALTER TABLE `staff`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=22;

--
-- AUTO_INCREMENT for table `suppliers`
--
ALTER TABLE `suppliers`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=2;

--
-- AUTO_INCREMENT for table `supplier_ledger`
--
ALTER TABLE `supplier_ledger`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Constraints for dumped tables
--

--
-- Constraints for table `account_deletion_requests`
--
ALTER TABLE `account_deletion_requests`
  ADD CONSTRAINT `account_deletion_requests_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `airline_users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `agency_deposits`
--
ALTER TABLE `agency_deposits`
  ADD CONSTRAINT `agency_deposits_ibfk_1` FOREIGN KEY (`agency_id`) REFERENCES `agencies` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `agency_deposits_ibfk_2` FOREIGN KEY (`account_id`) REFERENCES `accounts` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `agency_ledger`
--
ALTER TABLE `agency_ledger`
  ADD CONSTRAINT `agency_ledger_ibfk_1` FOREIGN KEY (`agency_id`) REFERENCES `agencies` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `agents`
--
ALTER TABLE `agents`
  ADD CONSTRAINT `agents_ibfk_1` FOREIGN KEY (`agency_id`) REFERENCES `agencies` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `aircrafts`
--
ALTER TABLE `aircrafts`
  ADD CONSTRAINT `aircrafts_ibfk_1` FOREIGN KEY (`category_id`) REFERENCES `Category` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `bookings`
--
ALTER TABLE `bookings`
  ADD CONSTRAINT `bookings_ibfk_1` FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `bookings_ibfk_2` FOREIGN KEY (`passenger_id`) REFERENCES `passengers` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `booking_passengers`
--
ALTER TABLE `booking_passengers`
  ADD CONSTRAINT `booking_passengers_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `booking_passengers_ibfk_2` FOREIGN KEY (`passenger_id`) REFERENCES `passengers` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `cargo_bookings`
--
ALTER TABLE `cargo_bookings`
  ADD CONSTRAINT `cargo_bookings_ibfk_1` FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `destinations`
--
ALTER TABLE `destinations`
  ADD CONSTRAINT `destinations_ibfk_1` FOREIGN KEY (`country_id`) REFERENCES `Country` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `device_tokens`
--
ALTER TABLE `device_tokens`
  ADD CONSTRAINT `device_tokens_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `airline_users` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `expenses`
--
ALTER TABLE `expenses`
  ADD CONSTRAINT `expenses_ibfk_3` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `expenses_ibfk_4` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `flight_crew`
--
ALTER TABLE `flight_crew`
  ADD CONSTRAINT `flight_crew_ibfk_1` FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `flight_crew_ibfk_2` FOREIGN KEY (`crew_id`) REFERENCES `crew` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `flight_series`
--
ALTER TABLE `flight_series`
  ADD CONSTRAINT `fk_flight_series_from_destination_id` FOREIGN KEY (`from_destination_id`) REFERENCES `destinations` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_flight_series_to_destination_id` FOREIGN KEY (`to_destination_id`) REFERENCES `destinations` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `fk_flight_series_via_destination_id` FOREIGN KEY (`via_destination_id`) REFERENCES `destinations` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `flight_series_ibfk_1` FOREIGN KEY (`aircraft_id`) REFERENCES `aircrafts` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `fueling`
--
ALTER TABLE `fueling`
  ADD CONSTRAINT `fueling_ibfk_1` FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series` (`id`),
  ADD CONSTRAINT `fueling_ibfk_2` FOREIGN KEY (`supplier_id`) REFERENCES `suppliers` (`id`),
  ADD CONSTRAINT `fueling_ibfk_3` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `luggage`
--
ALTER TABLE `luggage`
  ADD CONSTRAINT `luggage_ibfk_1` FOREIGN KEY (`passenger_id`) REFERENCES `passengers` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `luggage_ibfk_2` FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series` (`id`) ON DELETE SET NULL,
  ADD CONSTRAINT `luggage_ibfk_3` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`) ON DELETE SET NULL;

--
-- Constraints for table `notifications`
--
ALTER TABLE `notifications`
  ADD CONSTRAINT `notifications_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `airline_users` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `notifications_ibfk_2` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`);

--
-- Constraints for table `payment_transactions`
--
ALTER TABLE `payment_transactions`
  ADD CONSTRAINT `payment_transactions_ibfk_1` FOREIGN KEY (`booking_id`) REFERENCES `bookings` (`id`),
  ADD CONSTRAINT `payment_transactions_ibfk_2` FOREIGN KEY (`user_id`) REFERENCES `airline_users` (`id`);

--
-- Constraints for table `payroll`
--
ALTER TABLE `payroll`
  ADD CONSTRAINT `payroll_ibfk_1` FOREIGN KEY (`journal_entry_id`) REFERENCES `journal_entries` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `payroll_ibfk_2` FOREIGN KEY (`staff_id`) REFERENCES `staff` (`id`) ON DELETE CASCADE;

--
-- Constraints for table `seat_reservations`
--
ALTER TABLE `seat_reservations`
  ADD CONSTRAINT `seat_reservations_ibfk_1` FOREIGN KEY (`flight_series_id`) REFERENCES `flight_series` (`id`) ON DELETE CASCADE,
  ADD CONSTRAINT `seat_reservations_ibfk_2` FOREIGN KEY (`agent_id`) REFERENCES `agents` (`id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
