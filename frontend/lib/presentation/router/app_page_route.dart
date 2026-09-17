import 'package:flutter/material.dart';

import '../../shared/theme/design_tokens.dart';

/// Application page route with a calm fade + micro-slide transition.
///
/// Replaces the default platform transition with the Todo App's motion
/// language: a 280ms fade with a near-imperceptible vertical drift. The
/// transition is a one-shot animation, so `pumpAndSettle` (and route
/// observers) settle exactly as with [MaterialPageRoute]. When the user opts
/// out of animations the route content is rendered without motion.
class AppPageRoute<T> extends PageRouteBuilder<T> {
  AppPageRoute({
    required WidgetBuilder builder,
    required RouteSettings settings,
  }) : super(
         settings: settings,
         transitionDuration: AppDurations.page,
         reverseTransitionDuration: AppDurations.fast,
         pageBuilder: (context, animation, secondaryAnimation) =>
             builder(context),
         transitionsBuilder: (context, animation, secondaryAnimation, child) {
           if (MediaQuery.disableAnimationsOf(context)) return child;
           final curved = CurvedAnimation(
             parent: animation,
             curve: AppCurves.enter,
             reverseCurve: AppCurves.exit,
           );
           return FadeTransition(
             opacity: curved,
             child: SlideTransition(
               position: Tween<Offset>(
                 begin: const Offset(0, 0.015),
                 end: Offset.zero,
               ).animate(curved),
               child: child,
             ),
           );
         },
       );
}
