import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/supabase_config.dart';
import '../models/class_model.dart';
import '../models/assignment_model.dart';
import '../services/class_service.dart';
import '../services/assignment_service.dart';
import 'login.dart';
import 'class_detail_page.dart';

class StudentHomePage extends StatefulWidget {
  @override
  _StudentHomePageState createState() => _StudentHomePageState();
}

class _StudentHomePageState extends State<StudentHomePage> {
  String? userName;
  int _selectedIndex = 0;
  bool _isLoading = true;
  List<ClassModel> _classes = [];
  List<AssignmentModel> _dueAssignments = [];
  Map<String, int> _classAssignmentCounts = {};

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadClasses();
    _loadDueAssignments();
  }

  Future<void> _loadUserProfile() async {
    final user = await supabase.auth.currentUser;
    if (user != null) {
      final profile = await supabase
          .from('profiles')
          .select('name')
          .eq('id', user.id)
          .single();
      setState(() {
        userName = profile['name'];
      });
    }
  }

  Future<void> _loadClasses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final user = await supabase.auth.currentUser;
      if (user != null) {
        final classes = await ClassService.getStudentClasses(user.id);
        
        final assignmentCountsFutures = classes.map((classModel) async {
          return {
            'classId': classModel.id,
            'count': await AssignmentService.getAssignmentDueCount(classModel.id),
          };
        }).toList();
        
        final assignmentCounts = await Future.wait(assignmentCountsFutures);
        
        setState(() {
          _classes = classes;
          
          for (var item in assignmentCounts) {
            _classAssignmentCounts[item['classId'].toString()] = (item['count'] as num).toInt();
          }
        });
      }
    } catch (e) {
      print('Error loading classes: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadDueAssignments() async {
    try {
      final user = await supabase.auth.currentUser;
      if (user != null) {
        final assignments = await AssignmentService.getDueAssignments(user.id);
        setState(() {
          _dueAssignments = assignments;
        });
      }
    } catch (e) {
      print('Error loading due assignments: $e');
    }
  }

  Future<void> _signOut() async {
    await AuthService.signOut();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginPage()),
    );
  }

  void _onNavItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _joinClass() async {
    final TextEditingController codeController = TextEditingController();
    
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Join Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Enter the class code provided by your teacher'),
            SizedBox(height: 16),
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: 'Class Code',
                hintText: 'e.g., AB12CD',
              ),
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (codeController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please enter a class code')),
                );
                return;
              }
              
              Navigator.pop(context, codeController.text.trim().toUpperCase());
            },
            child: Text('Join'),
          ),
        ],
      ),
    );
    
    if (code != null) {
      final user = await supabase.auth.currentUser;
      if (user != null) {
        try {
          setState(() {
            _isLoading = true;
          });
          
          final classModel = await ClassService.joinClassWithCode(code, user.id);
          
          if (classModel != null) {
            await _loadClasses();
            await _loadDueAssignments();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Successfully joined ${classModel.name}!')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Invalid class code')),
            );
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error joining class: $e')),
          );
        } finally {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Row(
          children: [
            Image.asset(
              'images/classroom_icon.png', // Add your app icon here
              height: 32,
              errorBuilder: (context, error, stackTrace) => Icon(Icons.school),
            ),
            SizedBox(width: 12),
            Text(
              'EduAssist',
              style: TextStyle(
                color: Colors.grey[800],
                fontFamily: 'Nexa',
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today, color: Colors.grey[800]),
            onPressed: () {
              setState(() {
                _selectedIndex = 1; // Switch to calendar view
              });
            },
            tooltip: 'Calendar',
          ),
          PopupMenuButton(
            icon: CircleAvatar(
              backgroundColor: Colors.blue[100],
              child: Text(
                userName?.substring(0, 1).toUpperCase() ?? 'S',
                style: TextStyle(color: Colors.blue[900]),
              ),
            ),
            offset: Offset(0, 50),
            itemBuilder: (context) => [
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.grey[700]),
                    SizedBox(width: 12),
                    Text('Profile'),
                  ],
                ),
                value: 'profile',
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.grey[700]),
                    SizedBox(width: 12),
                    Text('Notifications'),
                  ],
                ),
                value: 'notifications',
              ),
              PopupMenuItem(
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.grey[700]),
                    SizedBox(width: 12),
                    Text('Logout'),
                  ],
                ),
                value: 'logout',
              ),
            ],
            onSelected: (value) {
              if (value == 'logout') {
                _signOut();
              }
            },
          ),
          SizedBox(width: 16),
        ],
      ),
      body: Row(
        children: [
          // Left Navigation Rail
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onNavItemTapped,
            labelType: NavigationRailLabelType.selected,
            backgroundColor: Colors.white,
            destinations: [
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Classes'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.calendar_today_outlined),
                selectedIcon: Icon(Icons.calendar_today),
                label: Text('Calendar'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_outlined),
                selectedIcon: Icon(Icons.assignment),
                label: Text('To-do'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.archive_outlined),
                selectedIcon: Icon(Icons.archive),
                label: Text('Archived'),
              ),
            ],
          ),
          // Main Content Area
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: _selectedIndex == 0
                  ? _buildClassesView()
                  : _selectedIndex == 1
                      ? _buildCalendarView()
                      : _selectedIndex == 2
                          ? _buildToDoView()
                          : _buildArchivedView(),
            ),
          ),
        ],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton.extended(
              onPressed: _joinClass,
              label: Text('Join Class'),
              icon: Icon(Icons.add),
              backgroundColor: Colors.blue,
            )
          : null,
    );
  }

  Widget _buildClassesView() {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, ${userName ?? "Student"}!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
                SizedBox(height: 24),
                _classes.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.class_outlined,
                              size: 80,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No classes yet',
                              style: TextStyle(
                                fontSize: 20,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Join a class using a code from your teacher',
                              style: TextStyle(
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: _joinClass,
                              icon: Icon(Icons.add),
                              label: Text('Join Class'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Expanded(
                        child: GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: MediaQuery.of(context).size.width > 1200 ? 4 : 3,
                            crossAxisSpacing: 24,
                            mainAxisSpacing: 24,
                            childAspectRatio: 1.3,
                          ),
                          itemCount: _classes.length,
                          itemBuilder: (context, index) {
                            final classModel = _classes[index];
                            return _buildClassCard(
                              classModel,
                              _classAssignmentCounts[classModel.id.toString()] ?? 0,
                            );
                          },
                        ),
                      ),
              ],
            ),
          );
  }

  Widget _buildCalendarView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Calendar View',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Track assignment due dates and important events',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToDoView() {
    return Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your To-Do List',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          SizedBox(height: 24),
          _dueAssignments.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No upcoming assignments',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Take a break or get ahead on your reading',
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : Expanded(
                  child: ListView.builder(
                    itemCount: _dueAssignments.length,
                    itemBuilder: (context, index) {
                      final assignment = _dueAssignments[index];
                      return _buildAssignmentCard(assignment);
                    },
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildArchivedView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.archive_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'Archived Classes',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Access your archived classes',
            style: TextStyle(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(ClassModel classModel, int assignmentCount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        onTap: () {
          // Navigate to class detail
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ClassDetailPage(classModel: classModel),
            ),
          ).then((_) {
            // Refresh data when returning from detail page
            _loadDueAssignments();
            _loadClasses();
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: classModel.color,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              padding: EdgeInsets.all(16),
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    classModel.name,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    classModel.subject,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.assignment_outlined, size: 20, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        '$assignmentCount assignments due soon',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.star_outline, size: 20, color: Colors.grey[600]),
                      SizedBox(width: 8),
                      Text(
                        'Overall Grade: A',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignmentCard(AssignmentModel assignment) {
    final now = DateTime.now();
    final daysUntilDue = assignment.dueDate.difference(now).inDays;
    final hoursUntilDue = assignment.dueDate.difference(now).inHours;
    
    String dueText;
    Color dueColor;
    
    if (daysUntilDue == 0) {
      dueText = 'Due today';
      dueColor = Colors.orange;
    } else if (daysUntilDue < 0) {
      dueText = 'Past due';
      dueColor = Colors.red;
    } else if (daysUntilDue == 1) {
      dueText = 'Due tomorrow';
      dueColor = Colors.orange;
    } else if (daysUntilDue < 3) {
      dueText = 'Due in $daysUntilDue days';
      dueColor = Colors.orange;
    } else {
      dueText = 'Due in $daysUntilDue days';
      dueColor = Colors.green;
    }
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Icon(Icons.assignment, color: Colors.white),
        ),
        title: Text(assignment.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 4),
            Text(
              dueText,
              style: TextStyle(
                color: dueColor,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 4),
            FutureBuilder<String>(
              future: _getClassName(assignment.classId),
              builder: (context, snapshot) {
                return Text(
                  snapshot.hasData ? snapshot.data! : 'Class',
                  style: TextStyle(color: Colors.grey[600]),
                );
              },
            ),
          ],
        ),
        trailing: OutlinedButton(
          onPressed: () {
            // View assignment details
          },
          child: Text('View'),
        ),
        onTap: () {
          // View assignment details
        },
      ),
    );
  }

  Future<String> _getTeacherName(String teacherId) async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('name')
          .eq('id', teacherId)
          .single();
      
      return profile['name'];
    } catch (e) {
      print('Error getting teacher name: $e');
      return 'Teacher';
    }
  }

  Future<String> _getClassName(String classId) async {
    try {
      final classData = await supabase
          .from('classes')
          .select('name')
          .eq('id', classId)
          .single();
      
      return classData['name'];
    } catch (e) {
      print('Error getting class name: $e');
      return 'Class';
    }
  }

  Future<String> _getClassGrade(String classId) async {
    // This would normally fetch the student's actual grade for this class
    // For now, we'll return a placeholder grade
    return 'A';
  }
} 