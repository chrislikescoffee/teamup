import 'package:flutter/material.dart';

class GameConfig {
  // --- ROUND SETTINGS ---
  static const int initialRoundDurationMs = 60000; // 2 Minutes
  static const int minRoundDurationMs = 45000;      // Floor of 45 seconds
  static const int roundDurationDecrementMs = 15000; // Time lost per round level

  // --- INSTRUCTION SETTINGS ---
  static const int initialInstructionSeconds = 15;
  static const int minInstructionSeconds = 5;
  static const int instructionDecrementInterval = 3; // Rounds before it gets faster

  // --- SEQUENCE SETTINGS ---
  static const int minSequenceLength = 3;
  static const int maxSequenceLength = 6;
  static const int roundsPerSequenceScaling = 2; // How often codes get longer

  // --- GAMEPLAY BALANCE ---
  static const double sliderMinMovementPercent = 0.25; // 25% movement required
  static const double analogEpsilon = 0.05;           // Precision for Dials/Sliders
  static const int maxRedundancyAttempts = 15;        // How hard to try for a new setting

  static const double chanceOfSelfInstruction = 0.2; // 20% chance to get your own control

  static const double sequenceTimeMultiplier = 2.0; // Give more time for codes

  // --- VISUAL FEEDBACK SETTINGS ---
  static const int successAnimationMs = 600;
  static const double successScaleSwell = 1.25;
  static const double successScaleNormal = 1.0;
  static const int successSwellWeight = 30; // % of time spent growing
  static const int successBounceWeight = 70; // % of time spent settling
  static const int feedbackAnimationMs = 800; // Total duration for the 2 flashes

  // --- COLORS AND STYLES ---
  static const Color successColor = Colors.greenAccent;
  static const Color instructionColor = Colors.white;
  static const double instructionFontSize = 24.0;
  static const double progressBarHeight = 8.0;
}