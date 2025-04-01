-- Table for user profiles
CREATE TABLE IF NOT EXISTS profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  name TEXT NOT NULL,
  email TEXT NOT NULL,
  role TEXT NOT NULL,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for classes
CREATE TABLE IF NOT EXISTS classes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name TEXT NOT NULL,
  subject TEXT NOT NULL,
  teacher_id UUID NOT NULL REFERENCES profiles(id),
  description TEXT,
  color INTEGER,
  banner_url TEXT,
  archived BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for class enrollment
CREATE TABLE IF NOT EXISTS enrollments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id UUID NOT NULL REFERENCES classes(id),
  student_id UUID NOT NULL REFERENCES profiles(id),
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(class_id, student_id)
);

-- Table for assignments
CREATE TABLE IF NOT EXISTS assignments (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  class_id UUID NOT NULL REFERENCES classes(id),
  teacher_id UUID NOT NULL REFERENCES profiles(id),
  max_points INTEGER,
  file_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  due_date TIMESTAMP WITH TIME ZONE NOT NULL
);

-- Table for submissions
CREATE TABLE IF NOT EXISTS submissions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  assignment_id UUID NOT NULL REFERENCES assignments(id),
  student_id UUID NOT NULL REFERENCES profiles(id),
  file_url TEXT,
  grade INTEGER,
  feedback TEXT,
  submitted_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(assignment_id, student_id)
);

-- Table for feedback
CREATE TABLE IF NOT EXISTS feedback (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  submission_id UUID NOT NULL REFERENCES submissions(id),
  teacher_id UUID NOT NULL REFERENCES profiles(id),
  content TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Table for class join codes
CREATE TABLE IF NOT EXISTS class_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id UUID NOT NULL REFERENCES classes(id),
  code TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days')
);

-- Enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_codes ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY IF NOT EXISTS "Users can view their own profile" 
  ON profiles FOR SELECT 
  USING (auth.uid() = id);

CREATE POLICY IF NOT EXISTS "Users can update their own profile" 
  ON profiles FOR UPDATE
  USING (auth.uid() = id);

-- Classes policies
CREATE POLICY IF NOT EXISTS "Teachers can create classes" 
  ON classes FOR INSERT 
  WITH CHECK (teacher_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Teachers can view their own classes" 
  ON classes FOR SELECT 
  USING (teacher_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Students can view classes they're enrolled in" 
  ON classes FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM enrollments 
      WHERE enrollments.class_id = id 
      AND enrollments.student_id = auth.uid()
    )
  );

-- Enrollments policies
CREATE POLICY IF NOT EXISTS "Students can view their enrollments" 
  ON enrollments FOR SELECT 
  USING (student_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Teachers can view enrollments for their classes" 
  ON enrollments FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM classes 
      WHERE classes.id = class_id 
      AND classes.teacher_id = auth.uid()
    )
  );

-- Assignments policies
CREATE POLICY IF NOT EXISTS "Teachers can create assignments" 
  ON assignments FOR INSERT 
  WITH CHECK (teacher_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Teachers can view assignments for their classes" 
  ON assignments FOR SELECT 
  USING (teacher_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Students can view assignments for classes they're enrolled in" 
  ON assignments FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM enrollments 
      WHERE enrollments.class_id = class_id 
      AND enrollments.student_id = auth.uid()
    )
  );

-- Submissions policies
CREATE POLICY IF NOT EXISTS "Students can submit assignments" 
  ON submissions FOR INSERT 
  WITH CHECK (student_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Students can view their own submissions" 
  ON submissions FOR SELECT 
  USING (student_id = auth.uid());

CREATE POLICY IF NOT EXISTS "Teachers can view submissions for their assignments" 
  ON submissions FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM assignments 
      WHERE assignments.id = assignment_id 
      AND assignments.teacher_id = auth.uid()
    )
  );

-- Class codes policies
CREATE POLICY IF NOT EXISTS "Teachers can create class codes" 
  ON class_codes FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM classes 
      WHERE classes.id = class_id 
      AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY IF NOT EXISTS "Anyone can view class codes" 
  ON class_codes FOR SELECT 
  USING (true);

-- Drop conflicting policies first (adding a DO block to handle errors gracefully)
DO $$
BEGIN
    -- Attempt to drop existing policies if they exist
    BEGIN
        DROP POLICY IF EXISTS "Teachers can create classes" ON classes;
    EXCEPTION WHEN undefined_object THEN
        -- Policy doesn't exist, do nothing
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Teachers can view their own classes" ON classes;
    EXCEPTION WHEN undefined_object THEN
        -- Policy doesn't exist, do nothing
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Students can view classes they're enrolled in" ON classes;
    EXCEPTION WHEN undefined_object THEN
        -- Policy doesn't exist, do nothing
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Students can view their enrollments" ON enrollments;
    EXCEPTION WHEN undefined_object THEN
        -- Policy doesn't exist, do nothing
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Teachers can view enrollments for their classes" ON enrollments;
    EXCEPTION WHEN undefined_object THEN
        -- Policy doesn't exist, do nothing
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Teachers can create class codes" ON class_codes;
    EXCEPTION WHEN undefined_object THEN
        -- Policy doesn't exist, do nothing
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Anyone can view class codes" ON class_codes;
    EXCEPTION WHEN undefined_object THEN
        -- Policy doesn't exist, do nothing
    END;
    
    BEGIN
        DROP POLICY IF EXISTS "Students can view assignments for classes they're enrolled in" ON assignments;
    EXCEPTION WHEN undefined_object THEN
        -- Policy doesn't exist, do nothing
    END;
END
$$;

-- Classes policies
CREATE POLICY "Teachers can create classes" 
  ON classes FOR INSERT 
  WITH CHECK (teacher_id = auth.uid());

CREATE POLICY "Teachers can view their own classes" 
  ON classes FOR SELECT 
  USING (teacher_id = auth.uid());

CREATE POLICY "Students can view classes they're enrolled in" 
  ON classes FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM enrollments 
      WHERE enrollments.class_id = id 
      AND enrollments.student_id = auth.uid()
    )
  );

-- Enrollments policies
CREATE POLICY "Students can view their enrollments" 
  ON enrollments FOR SELECT 
  USING (student_id = auth.uid());

CREATE POLICY "Teachers can view enrollments for their classes" 
  ON enrollments FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM classes 
      WHERE classes.id = class_id 
      AND classes.teacher_id = auth.uid()
    )
  );

-- Add insertion policy for enrollments
CREATE POLICY "Students can enroll in classes" 
  ON enrollments FOR INSERT 
  WITH CHECK (student_id = auth.uid());

-- Class codes policies
CREATE POLICY "Teachers can create class codes" 
  ON class_codes FOR INSERT 
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM classes 
      WHERE classes.id = class_id 
      AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Anyone can view class codes" 
  ON class_codes FOR SELECT 
  USING (true);

-- Update assignments policies for class_id
CREATE POLICY "Students can view assignments for classes they're enrolled in" 
  ON assignments FOR SELECT 
  USING (
    EXISTS (
      SELECT 1 FROM enrollments 
      WHERE enrollments.class_id = class_id 
      AND enrollments.student_id = auth.uid()
    )
  );

-- Add missing columns to existing assignments table
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES classes(id);
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS max_points INTEGER; 