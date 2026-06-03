import 'package:flutter/material.dart';
import 'generated/design_tokens.g.dart';

// ============================================================================
// Viva (patient-app) — theme tokens
// ============================================================================
//
// PART 13 Layer D1.1 (2026-05-25) — consumes generated tokens from
// `core/generated/design_tokens.g.dart`, which are emitted from
// `apps/web/src/shared/theme/palettes.ts` by
// `scripts/design-tokens/generate-dart-design-tokens.ts`.
//
// Aligned tokens (code-generated from web SSoT):
//   - kError        ←→ SEVERITY_COLORS.critical (#B0413E muted terracotta;
//                       replaces prior #D32F2F panic-red per the
//                       alert-fatigue principle).
//   - kSuccess      ←→ SEVERITY_COLORS.success  (#4A7C59 forest green)
//   - kWarning      ←→ SEVERITY_COLORS.warning  (#D97706 deep amber)
//   - kInfo         ←→ SEVERITY_COLORS.info     (#2E5C8A deep teal)
//   - kSafetyActionMinSize ←→ TOUCH_TARGETS.safetyAction (56pt; mental-health
//                       crisis-flow surfaces — emergency contact button,
//                       break-glass actions, "I'm not safe" disclosures).
//   - VivaText.body ←→ FONT_SIZES.patientApp (18 px senior-accessibility
//                       baseline — mental-health patient demographic often
//                       includes older adults).
//
// Identity tokens (intentionally distinct from web — patient-app brand):
//   - kPrimary purple #7B1FA2 — Viva's signature; distinct from clinician
//     web's `signacare` ochre. F2 (patient-app default theme change) remains
//     HARD-GATED behind explicit operator Q2 reversal.

// ---- Identity colours (Viva brand — DO NOT change without F2 gate) ----
const kPrimary = Color(0xFF7B1FA2);      // Purple — Viva signature
const kPrimaryLight = Color(0xFFCE93D8);
const kAccent = Color(0xFFFF6F00);        // Warm amber for CTAs
const kSurface = Color(0xFFF8F5FA);       // Light lavender
const kText = Color(0xFF2D2D3A);
const kTextLight = Color(0xFF8E8E9A);
const kDivider = Color(0xFFE8E4EC);

// ---- Severity colours (PART 13 Layer A SSoT — mirror of web SEVERITY_COLORS) ----
const kSuccess = SignacareDesignTokens.severitySuccess; // Forest green (was #2E7D32; muted alignment)
const kWarning = SignacareDesignTokens.severityWarning; // Deep amber (was #F57C00; SSoT alignment)
const kError = SignacareDesignTokens.severityCritical;  // Muted terracotta — REPLACES #D32F2F
                                    // Material panic-red per the
                                    // alert-fatigue principle. Pair with
                                    // icon + text label per principle #3.
const kInfo = SignacareDesignTokens.severityInfo;       // Deep teal (was #0288D1; SSoT alignment)
const kNeutral = SignacareDesignTokens.severityNeutral; // Slate (disabled / informational)

// ---- Tracking colours (Viva-specific; not on the severity axis) ----
const kMood = Color(0xFFFF6F00);
const kEnergy = Color(0xFF43A047);
const kSleep = Color(0xFF5C6BC0);
const kPain = Color(0xFFE53935);
const kMeds = Color(0xFF00897B);

// ---- Touch-target SSoT (mirror of TOUCH_TARGETS in web palettes.ts) ----
//
// kSafetyActionMinSize is the 56pt hit-box for mental-health crisis-flow
// surfaces — emergency-contact button on EmergencyScreen, break-glass
// disclosure on home, "I'm not safe" surfacing, restrictive-intervention
// acknowledge. Apply as: ElevatedButton.styleFrom(minimumSize: kSafetyActionMinSize)
const kTouchTargetStandard = Size(double.infinity, 48); // 48pt height = above WCAG 44pt floor
const kSafetyActionMinSize = Size(
  SignacareDesignTokens.touchTargetSafetyActionPx,
  SignacareDesignTokens.touchTargetSafetyActionPx,
); // 56pt × 56pt mental-health safety actions

// ---- Patient-app font scale (PART 13 Layer D1.1 — senior accessibility) ----
//
// Mirror of FONT_SIZES.patientApp = 18px (Layer A3). Mental-health patient
// demographics often include older adults; the +2 px bump over the web
// clinician default (16 px) honours Health Literacy Online recommendations.
const _kPatientBody = SignacareDesignTokens.appBodySizePx;      // up from 14 — senior accessibility baseline
const _kPatientBodySmall = SignacareDesignTokens.fontSizeBodyPx; // up from 12 — secondary content
const _kPatientTitle = 22.0;       // up from 16
const _kPatientHeading = 26.0;     // up from 20
const _kPatientCaption = SignacareDesignTokens.fontSizeBodySmallPx; // up from 12 — timestamps, badges
const _kPatientAppBar = 19.0;      // up from 17 — top-of-screen titles

// Tabular figures feature set for numeric content (vitals, scores, doses,
// schedule times). Equal-width digits prevent row-to-row misread on
// aligned columns. Pairs with FontFeature.liningFigures() so digits sit
// on the baseline (standard for clinical-data display).
const List<FontFeature> kTabularFigures = <FontFeature>[
  FontFeature.tabularFigures(),
  FontFeature.liningFigures(),
];

final vivaTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: kPrimary,
  brightness: Brightness.light,
  scaffoldBackgroundColor: kSurface,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: kText,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: _kPatientAppBar,
      fontWeight: FontWeight.w700,
      color: kText,
      fontFeatures: kTabularFigures,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: kPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      // 48pt minimum height (above WCAG 2.1 / iOS HIG 44pt floor) for general
      // patient actions. Safety-critical actions (emergency contact, crisis
      // disclosure) MUST override this with `minimumSize: kSafetyActionMinSize`
      // to get the 56pt × 56pt safety target.
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: kTabularFigures,
      ),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: kPrimary,
      side: const BorderSide(color: kPrimary),
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDivider)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kDivider)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kError, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: kTextLight, fontSize: 15),
    // 16 px minimum on text inputs prevents iOS auto-zoom-on-focus.
    hintStyle: const TextStyle(color: kTextLight, fontSize: 16),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: kDivider)),
    color: Colors.white,
  ),
  chipTheme: ChipThemeData(
    backgroundColor: kSurface,
    selectedColor: kPrimary.withAlpha(25),
    labelStyle: const TextStyle(fontSize: _kPatientCaption),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    side: const BorderSide(color: kDivider),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: kPrimary,
    unselectedItemColor: kTextLight,
    type: BottomNavigationBarType.fixed,
    backgroundColor: Colors.white,
    elevation: 8,
    // Bottom nav labels — 14 px (above WCAG comfort floor) with tabular nums
    // in case any nav label includes a count badge.
    selectedLabelStyle: TextStyle(fontSize: _kPatientCaption, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontSize: _kPatientCaption),
  ),
);

// VivaText — patient-app typography scale (senior-accessibility baseline).
// All numeric-bearing styles enable tabular figures so vitals, doses,
// schedule times, and assessment scores align across rows.
class VivaText {
  static const heading = TextStyle(
    fontSize: _kPatientHeading,
    fontWeight: FontWeight.w700,
    color: kText,
    height: 1.2,
    fontFeatures: kTabularFigures,
  );
  static const title = TextStyle(
    fontSize: _kPatientTitle,
    fontWeight: FontWeight.w600,
    color: kText,
    height: 1.3,
    fontFeatures: kTabularFigures,
  );
  static const body = TextStyle(
    fontSize: _kPatientBody,
    color: kText,
    height: 1.5,
    fontFeatures: kTabularFigures,
  );
  static const bodySmall = TextStyle(
    fontSize: _kPatientBodySmall,
    color: kText,
    height: 1.4,
    fontFeatures: kTabularFigures,
  );
  static const caption = TextStyle(
    fontSize: _kPatientCaption,
    color: kTextLight,
    height: 1.4,
    fontFeatures: kTabularFigures,
  );
  /// Numeric-emphasis style (vitals, scores, dose values) — slight weight
  /// bump over body for visual lock against row-to-row misread on aligned
  /// columns. Equivalent of MUI's `<Typography variant="data">` on the web.
  static const data = TextStyle(
    fontSize: _kPatientBody,
    fontWeight: FontWeight.w500,
    color: kText,
    height: 1.4,
    fontFeatures: kTabularFigures,
  );
}

// ============================================================================
// vivaWarmthTheme — PART 13 Layer B2 + D1.1 (patient-warmth palette,
// AVAILABLE but NOT default per operator Q2 / F2 HARD gate)
// ============================================================================
//
// Parallel ThemeData using the web-side `warmth` palette
// (apps/web/src/shared/theme/palettes.ts THEME_PALETTES.warmth). Use when a
// future patient-app theme picker is added, or when a per-clinic branding
// flag opts the patient app into the warmth palette. Current default
// (vivaTheme above, purple) is unchanged.

// Warmth-palette tokens (mirror of web `warmth` THEME_PALETTE). Material 3
// derives secondary/tertiary from the seed (`_kWarmthPrimary`) automatically
// when `colorSchemeSeed:` is used, so `secondary` / `sidebar` are not
// declared as standalone constants here — they would be needed only if a
// dedicated Sidebar/Drawer widget read them directly (none in Viva today).
// Re-add `_kWarmthSecondary` + `_kWarmthSidebar` here when a sidebar widget
// is introduced (parity with web sidebar tokens), under their own
// `// ignore: unused_element` removal at that time.
const _kWarmthPrimary = Color(0xFF8E5A3C);      // warm walnut
const _kWarmthSidebarText = Color(0xFFFAEDE0);  // warm cream — used as
                                                 // unselected bottom-nav text
const _kWarmthBackground = Color(0xFFFCF8F3);   // warm parchment
const _kWarmthText = Color(0xFF2E2218);         // deep brown
const _kWarmthAccent = Color(0xFFD4A574);       // apricot

final vivaWarmthTheme = ThemeData(
  useMaterial3: true,
  colorSchemeSeed: _kWarmthPrimary,
  brightness: Brightness.light,
  scaffoldBackgroundColor: _kWarmthBackground,
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: _kWarmthText,
    elevation: 0,
    centerTitle: true,
    titleTextStyle: TextStyle(
      fontSize: _kPatientAppBar,
      fontWeight: FontWeight.w700,
      color: _kWarmthText,
      fontFeatures: kTabularFigures,
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: _kWarmthPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size.fromHeight(48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        fontFeatures: kTabularFigures,
      ),
    ),
  ),
  // Other component themes mirror vivaTheme; only colour-bearing fields differ.
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kWarmthAccent)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kWarmthAccent)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kWarmthPrimary, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kError, width: 1.5)),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    labelStyle: const TextStyle(color: _kWarmthText, fontSize: 15),
    hintStyle: TextStyle(color: _kWarmthSidebarText.withAlpha(180), fontSize: 16),
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: _kWarmthAccent.withAlpha(80)),
    ),
    color: Colors.white,
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    selectedItemColor: _kWarmthPrimary,
    unselectedItemColor: _kWarmthSidebarText,
    type: BottomNavigationBarType.fixed,
    backgroundColor: Colors.white,
    elevation: 8,
    selectedLabelStyle: TextStyle(fontSize: _kPatientCaption, fontWeight: FontWeight.w600),
    unselectedLabelStyle: TextStyle(fontSize: _kPatientCaption),
  ),
);
