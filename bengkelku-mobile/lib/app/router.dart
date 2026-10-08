import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:go_router/go_router.dart";

import "../core/demo/demo_data.dart";
import "../core/network/supabase_client.dart";

// Auth & Location
import "../features/auth/presentation/forgot_password_screen.dart";
import "../features/auth/presentation/login_screen.dart";
import "../features/location/presentation/location_screen.dart";

// Discovery & Detail
import "../features/workshops/presentation/home_screen.dart";
import "../features/workshops/presentation/map_screen.dart";
import "../features/workshops/presentation/nearby_screen.dart";
import "../features/workshops/presentation/workshop_detail_screen.dart";

// Booking & Payment
import "../features/booking/presentation/booking_list_screen.dart";
import "../features/booking/presentation/booking_summary_screen.dart";
import "../features/booking/presentation/booking_ticket_screen.dart";
import "../features/booking/presentation/payment_screen.dart";
import "../features/booking/presentation/payment_status_screens.dart";
import "../features/booking/presentation/schedule_screen.dart";

// Garage & Oil
import "../features/garage/presentation/garage_screen.dart";
import "../features/oil/presentation/oil_detail_screen.dart";

// Favorites, Notifications, Reviews, Profile
import "../features/favorites/presentation/favorites_screen.dart";
import "../features/notifications/presentation/notification_settings_screen.dart";
import "../features/notifications/presentation/notifications_screen.dart";
import "../features/profile/presentation/profile_screen.dart";
import "../features/reviews/presentation/rate_form_screen.dart";
import "../features/reviews/presentation/review_list_screen.dart";

// Owner
import "../features/owner/presentation/bank_account_screen.dart";
import "../features/owner/presentation/owner_dashboard_screen.dart";
import "../features/owner/presentation/owner_record_screen.dart";
import "../features/owner/presentation/owner_reviews_screen.dart";
import "../features/owner/presentation/owner_scan_screen.dart";
import "../features/owner/presentation/owner_schedule_screen.dart";
import "../features/owner/presentation/owner_wallet_screen.dart";
import "../features/owner/presentation/payout_detail_screen.dart";
import "../features/owner/presentation/reg_status_screen.dart";
import "../features/owner/presentation/reg_verify_screen.dart";

// Chat (v1.3)
import "../features/chat/presentation/chat_list_screen.dart";
import "../features/chat/presentation/chat_room_screen.dart";

// Bantuan Darurat / SOS (v1.3)
import "../features/sos/presentation/sos_form_screen.dart";
import "../features/sos/presentation/sos_pay_screen.dart";
import "../features/sos/presentation/sos_searching_screen.dart";
import "../features/sos/presentation/sos_tracking_screen.dart";
import "../features/sos/presentation/sos_quote_screen.dart";
import "../features/sos/presentation/sos_done_screen.dart";

// Bantuan Darurat sisi bengkel (v1.3)
import "../features/sos/presentation/owner_quote_form_screen.dart";
import "../features/sos/presentation/owner_sos_offer_screen.dart";
import "../features/sos/presentation/owner_sos_route_screen.dart";
import "../features/sos/presentation/owner_standby_screen.dart";

// Pusat Bantuan (v1.3 Fitur F)
import "../features/support/data/support_models.dart";
import "../features/support/presentation/help_center_screen.dart";
import "../features/support/presentation/support_report_screen.dart";
import "../features/support/presentation/support_ticket_detail_screen.dart";
import "../features/support/presentation/support_tickets_screen.dart";

/// Router lengkap go_router untuk seluruh layar BengkelKu Mobile (Rider & Owner).
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: "/home",
    redirect: (context, state) {
      final loggedIn = kDemoPreview || SupabaseService.isLoggedIn;
      final loggingIn = state.matchedLocation == "/login" ||
          state.matchedLocation == "/forgot-password";

      if (!loggedIn && !loggingIn) return "/login";
      if (loggedIn && loggingIn) return "/home";
      return null;
    },
    routes: [
      GoRoute(
        path: "/login",
        builder: (c, s) => const LoginScreen(),
      ),
      GoRoute(
        path: "/forgot-password",
        builder: (c, s) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: "/location",
        builder: (c, s) => const LocationScreen(),
      ),
      GoRoute(
        path: "/home",
        builder: (c, s) => const HomeScreen(),
        routes: [
          GoRoute(
            path: "nearby",
            builder: (c, s) => const NearbyScreen(),
          ),
          GoRoute(
            path: "map",
            builder: (c, s) => const MapScreen(),
          ),
          GoRoute(
            path: "workshop/:id",
            builder: (c, s) => WorkshopDetailScreen(
              workshopId: s.pathParameters["id"] ?? "",
            ),
          ),
        ],
      ),
      GoRoute(
        path: "/schedule",
        builder: (c, s) => ScheduleScreen(
          workshopId: s.uri.queryParameters["workshopId"] ?? "",
          serviceIds: _csv(s.uri.queryParameters["services"]),
        ),
      ),
      GoRoute(
        path: "/summary",
        builder: (c, s) => BookingSummaryScreen(
          workshopId: s.uri.queryParameters["workshopId"] ?? "",
          serviceIds: _csv(s.uri.queryParameters["services"]),
          vehicleId: s.uri.queryParameters["vehicleId"],
          slot: DateTime.tryParse(s.uri.queryParameters["slot"] ?? "")?.toUtc(),
        ),
      ),
      GoRoute(
        path: "/payment",
        builder: (c, s) => PaymentScreen(
          bookingId: s.uri.queryParameters["bookingId"] ?? "",
        ),
      ),
      GoRoute(
        path: "/payment-success",
        builder: (c, s) => PaymentSuccessScreen(
          bookingId: s.uri.queryParameters["bookingId"] ?? "",
        ),
      ),
      GoRoute(
        path: "/payment-failed",
        builder: (c, s) => const PaymentFailedScreen(),
      ),
      GoRoute(
        path: "/ticket",
        builder: (c, s) => BookingTicketScreen(
          bookingId: s.uri.queryParameters["bookingId"] ?? "",
        ),
      ),
      GoRoute(
        path: "/bookings",
        builder: (c, s) => const BookingListScreen(),
      ),
      GoRoute(
        path: "/garage",
        builder: (c, s) => const GarageScreen(),
      ),
      GoRoute(
        path: "/oil-detail",
        builder: (c, s) => OilDetailScreen(
          vehicleId: s.uri.queryParameters["vehicleId"] ?? "",
        ),
      ),
      GoRoute(
        path: "/favorites",
        builder: (c, s) => const FavoritesScreen(),
      ),
      GoRoute(
        path: "/notifications",
        builder: (c, s) => const NotificationsScreen(),
        routes: [
          GoRoute(
            path: "settings",
            builder: (c, s) => const NotificationSettingsScreen(),
          ),
        ],
      ),
      GoRoute(
        path: "/reviews",
        builder: (c, s) => ReviewListScreen(
          workshopId: s.uri.queryParameters["workshopId"] ?? "",
        ),
      ),
      GoRoute(
        path: "/rate",
        builder: (c, s) => RateFormScreen(
          bookingId: s.uri.queryParameters["bookingId"] ?? "",
        ),
      ),
      GoRoute(
        path: "/profile",
        builder: (c, s) => const ProfileScreen(),
      ),

      // Route khusus Pemilik Bengkel (Owner)
      GoRoute(
        path: "/owner",
        builder: (c, s) => const OwnerDashboardScreen(),
        routes: [
          GoRoute(
            path: "register",
            builder: (c, s) => const RegVerifyScreen(),
          ),
          GoRoute(
            path: "status",
            builder: (c, s) => const RegStatusScreen(),
          ),
          GoRoute(
            path: "scan",
            builder: (c, s) => const OwnerScanScreen(),
          ),
          GoRoute(
            path: "schedule",
            builder: (c, s) => const OwnerScheduleScreen(),
          ),
          GoRoute(
            path: "record",
            builder: (c, s) => OwnerRecordScreen(
              bookingId: s.uri.queryParameters["bookingId"] ?? "",
            ),
          ),
          GoRoute(
            path: "reviews",
            builder: (c, s) => const OwnerReviewsScreen(),
          ),
          GoRoute(
            path: "wallet",
            builder: (c, s) => const OwnerWalletScreen(),
            routes: [
              GoRoute(
                path: "detail",
                builder: (c, s) => const PayoutDetailScreen(),
              ),
            ],
          ),
          GoRoute(
            path: "bank-account",
            builder: (c, s) => const BankAccountScreen(),
          ),
          // Bantuan Darurat sisi bengkel — PRD v1.3 Bagian 3.3 & 3.9
          GoRoute(
            path: "standby",
            builder: (c, s) => const OwnerStandbyScreen(),
          ),
          GoRoute(
            path: "sos/offer/:offerId",
            pageBuilder: (c, s) => MaterialPage(
              fullscreenDialog: true,
              child: OwnerSosOfferScreen(
                offerId: s.pathParameters["offerId"] ?? "",
              ),
            ),
          ),
          GoRoute(
            path: "sos/:requestId/route",
            builder: (c, s) => OwnerSosRouteScreen(
              requestId: s.pathParameters["requestId"] ?? "",
            ),
          ),
          GoRoute(
            path: "sos/:requestId/quote",
            builder: (c, s) => OwnerQuoteFormScreen(
              requestId: s.pathParameters["requestId"] ?? "",
            ),
          ),
        ],
      ),

      // Pusat Bantuan (v1.3) — PRD Bagian 7
      GoRoute(
        path: "/help",
        builder: (c, s) => const HelpCenterScreen(),
        routes: [
          GoRoute(
            path: "report",
            builder: (c, s) {
              final q = s.uri.queryParameters;
              final cat = q["category"];
              return SupportReportScreen(
                bookingId: q["bookingId"],
                sosRequestId: q["sosRequestId"],
                threadId: q["threadId"],
                initialCategory:
                    cat == null ? null : SupportCategoryX.parse(cat),
              );
            },
          ),
          GoRoute(
            path: "tickets",
            builder: (c, s) => const SupportTicketsScreen(),
          ),
          GoRoute(
            path: "tickets/:ticketId",
            builder: (c, s) => SupportTicketDetailScreen(
              ticketId: s.pathParameters["ticketId"] ?? "",
            ),
          ),
        ],
      ),

      // Chat (v1.3) — PRD Bagian 2
      GoRoute(
        path: "/chat",
        builder: (c, s) => const ChatListScreen(),
      ),
      GoRoute(
        path: "/chat/:threadId",
        builder: (c, s) => ChatRoomScreen(
          threadId: s.pathParameters["threadId"] ?? "",
          bookingCode: s.uri.queryParameters["bookingCode"],
        ),
      ),

      // Bantuan Darurat / SOS (v1.3) — PRD Bagian 3
      GoRoute(
        path: "/sos",
        builder: (c, s) => const SosFormScreen(),
        routes: [
          GoRoute(
            path: ":requestId/pay",
            builder: (c, s) => SosPayScreen(
              requestId: s.pathParameters["requestId"] ?? "",
            ),
          ),
          GoRoute(
            path: ":requestId/searching",
            builder: (c, s) => SosSearchingScreen(
              requestId: s.pathParameters["requestId"] ?? "",
            ),
          ),
          GoRoute(
            path: ":requestId/tracking",
            builder: (c, s) => SosTrackingScreen(
              requestId: s.pathParameters["requestId"] ?? "",
            ),
          ),
          GoRoute(
            path: ":requestId/quote",
            builder: (c, s) => SosQuoteScreen(
              requestId: s.pathParameters["requestId"] ?? "",
              quoteId: s.uri.queryParameters["quoteId"] ?? "",
            ),
          ),
          GoRoute(
            path: ":requestId/done",
            builder: (c, s) => SosDoneScreen(
              requestId: s.pathParameters["requestId"] ?? "",
            ),
          ),
        ],
      ),
    ],
  );
});

List<String> _csv(String? v) => (v ?? "")
    .split(",")
    .map((e) => e.trim())
    .where((e) => e.isNotEmpty)
    .toList();
