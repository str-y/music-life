import 'package:go_router/go_router.dart';

import 'routes.dart';

GoRouter buildAppRouter({String? initialLocation}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: $appRoutes,
  );
}
