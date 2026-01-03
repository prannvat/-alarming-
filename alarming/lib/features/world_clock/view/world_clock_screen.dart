import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../../../core/theme/app_theme.dart';

class WorldClockScreen extends StatefulWidget {
  const WorldClockScreen({super.key});

  @override
  State<WorldClockScreen> createState() => _WorldClockScreenState();
}

class _WorldClockScreenState extends State<WorldClockScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();
  bool _isEditing = false;
  
  // Selected cities
  final List<CityTime> _selectedCities = [
    CityTime(name: 'Cupertino', location: 'America/Los_Angeles'),
    CityTime(name: 'New York', location: 'America/New_York'),
    CityTime(name: 'London', location: 'Europe/London'),
    CityTime(name: 'Paris', location: 'Europe/Paris'),
    CityTime(name: 'Tokyo', location: 'Asia/Tokyo'),
    CityTime(name: 'Sydney', location: 'Australia/Sydney'),
  ];

  @override
  void initState() {
    super.initState();
    _initializeTimeZones();
    _startTimer();
  }

  Future<void> _initializeTimeZones() async {
    tz.initializeTimeZones();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now().toUtc();
        });
      }
    });
  }

  void _showSearchCityDialog() async {
    final result = await showSearch(
      context: context,
      delegate: CitySearchDelegate(),
    );

    if (result != null) {
      setState(() {
        // Check if already added
        if (!_selectedCities.any((c) => c.location == result.location)) {
          _selectedCities.add(result);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leadingWidth: 80,
        leading: TextButton(
          onPressed: () {
            setState(() {
              _isEditing = !_isEditing;
            });
          },
          child: Text(
            _isEditing ? 'Done' : 'Edit',
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 17,
            ),
            maxLines: 1,
            overflow: TextOverflow.visible,
          ),
        ),
        title: const Text(
          'World Clock',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 17,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: () {
              _showSearchCityDialog();
            },
            icon: const Icon(Icons.add, color: AppTheme.primary),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Text(
              'World Clock',
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Expanded(
            child: _isEditing 
              ? ReorderableListView.builder(
                  itemCount: _selectedCities.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (oldIndex < newIndex) {
                        newIndex -= 1;
                      }
                      final item = _selectedCities.removeAt(oldIndex);
                      _selectedCities.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final city = _selectedCities[index];
                    return Container(
                      key: ValueKey(city.location),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Color(0xFF2C2C2E), width: 1)),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              _selectedCities.removeAt(index);
                            });
                          },
                        ),
                        title: Text(
                          city.name,
                          style: const TextStyle(color: Colors.white, fontSize: 20),
                        ),
                        trailing: const Icon(Icons.drag_handle, color: Colors.grey),
                      ),
                    );
                  },
                )
              : ListView.separated(
                  itemCount: _selectedCities.length,
                  separatorBuilder: (context, index) => const Divider(
                    height: 1,
                    color: Color(0xFF2C2C2E),
                    indent: 16,
                  ),
                  itemBuilder: (context, index) {
                    return _buildCityItem(_selectedCities[index]);
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildCityItem(CityTime city) {
    // Calculate time for this city using timezone package
    DateTime cityTime;
    double offsetInHours;
    
    try {
      final location = tz.getLocation(city.location);
      final tzNow = tz.TZDateTime.now(location);
      cityTime = tzNow;
      offsetInHours = tzNow.timeZoneOffset.inMinutes / 60.0;
    } catch (e) {
      // Fallback if location not found
      cityTime = DateTime.now();
      offsetInHours = 0;
    }

    final localTime = DateTime.now();
    final timeDiff = offsetInHours - (localTime.timeZoneOffset.inMinutes / 60.0);
    
    String timeDiffString;
    // Format diff string (e.g. +5.5HRS)
    final diffAbs = timeDiff.abs();
    final diffHours = diffAbs.floor();
    final diffMinutes = ((diffAbs - diffHours) * 60).round();
    
    String diffText = '$diffHours';
    if (diffMinutes > 0) {
      diffText += ':${diffMinutes.toString().padLeft(2, '0')}';
    }
    diffText += 'HRS';
    
    if (timeDiff == 0) {
      timeDiffString = 'Today, +0HRS';
    } else if (timeDiff > 0) {
      timeDiffString = 'Today, +$diffText';
    } else {
      timeDiffString = 'Today, -$diffText';
    }

    // Check if it's tomorrow or yesterday relative to local time
    if (cityTime.day > localTime.day) {
      timeDiffString = 'Tomorrow, +$diffText';
    } else if (cityTime.day < localTime.day) {
      timeDiffString = 'Yesterday, -$diffText';
    }

    return Dismissible(
      key: Key(city.location),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Text(
          'Delete',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      onDismissed: (direction) {
        setState(() {
          _selectedCities.remove(city);
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        height: 90, 
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded( 
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    timeDiffString,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    city.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w400,
                    ),
                    overflow: TextOverflow.ellipsis, 
                  ),
                ],
              ),
            ),
            Row( 
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  DateFormat('h:mm').format(cityTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 50,
                    fontWeight: FontWeight.w200,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  DateFormat('a').format(cityTime),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CityTime {
  final String name;
  final String location; // Timezone ID (e.g. "America/New_York")

  CityTime({required this.name, required this.location});
}

class CitySearchDelegate extends SearchDelegate<CityTime?> {
  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      scaffoldBackgroundColor: const Color(0xFF1C1C1E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF1C1C1E),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: TextStyle(color: AppTheme.textSecondary),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.clear, color: AppTheme.primary),
        onPressed: () {
          query = '';
        },
      ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back, color: AppTheme.primary),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return _buildSearchResults();
  }

  Widget _buildSearchResults() {
    // Get all available timezones
    final locations = tz.timeZoneDatabase.locations.keys.toList();
    
    // Filter based on query
    final results = query.isEmpty
        ? []
        : locations.where((loc) {
            final name = loc.split('/').last.replaceAll('_', ' ');
            return name.toLowerCase().contains(query.toLowerCase());
          }).toList();

    return ListView.separated(
      itemCount: results.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFF2C2C2E)),
      itemBuilder: (context, index) {
        final location = results[index];
        // Format name: "America/New_York" -> "New York"
        final name = location.split('/').last.replaceAll('_', ' ');
        final region = location.split('/').first;
        
        return ListTile(
          title: Text(
            name,
            style: const TextStyle(color: Colors.white, fontSize: 17),
          ),
          subtitle: Text(
            region,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
          onTap: () {
            close(context, CityTime(name: name, location: location));
          },
        );
      },
    );
  }
}
