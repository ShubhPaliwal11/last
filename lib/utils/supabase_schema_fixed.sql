-- Create missing tables needed for the application

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

-- Table for class join codes
CREATE TABLE IF NOT EXISTS class_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  class_id UUID NOT NULL REFERENCES classes(id),
  code TEXT NOT NULL UNIQUE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  expires_at TIMESTAMP WITH TIME ZONE DEFAULT (CURRENT_TIMESTAMP + INTERVAL '7 days')
);

-- Add missing columns to existing assignments table
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS class_id UUID REFERENCES classes(id);
ALTER TABLE assignments ADD COLUMN IF NOT EXISTS max_points INTEGER;

-- Enable RLS on new tables
ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE enrollments ENABLE ROW LEVEL SECURITY;
ALTER TABLE class_codes ENABLE ROW LEVEL SECURITY;

-- First, drop any potentially conflicting policies
DO $$
BEGIN
    BEGIN DROP POLICY IF EXISTS "Teachers can create classes" ON classes; EXCEPTION WHEN undefined_object THEN NULL; END;
    BEGIN DROP POLICY IF EXISTS "Teachers can view their own classes" ON classes; EXCEPTION WHEN undefined_object THEN NULL; END;
    BEGIN DROP POLICY IF EXISTS "Students can view classes they're enrolled in" ON classes; EXCEPTION WHEN undefined_object THEN NULL; END;
    BEGIN DROP POLICY IF EXISTS "Students can view their enrollments" ON enrollments; EXCEPTION WHEN undefined_object THEN NULL; END;
    BEGIN DROP POLICY IF EXISTS "Teachers can view enrollments for their classes" ON enrollments; EXCEPTION WHEN undefined_object THEN NULL; END;
    BEGIN DROP POLICY IF EXISTS "Students can enroll in classes" ON enrollments; EXCEPTION WHEN undefined_object THEN NULL; END;
    BEGIN DROP POLICY IF EXISTS "Teachers can create class codes" ON class_codes; EXCEPTION WHEN undefined_object THEN NULL; END;
    BEGIN DROP POLICY IF EXISTS "Anyone can view class codes" ON class_codes; EXCEPTION WHEN undefined_object THEN NULL; END;
    BEGIN DROP POLICY IF EXISTS "Students can view assignments for classes they're enrolled in" ON assignments; EXCEPTION WHEN undefined_object THEN NULL; END;
END $$;

-- Add new policies for classes
CREATE POLICY "Teachers can create classes" ON classes 
  FOR INSERT WITH CHECK (teacher_id = auth.uid());

CREATE POLICY "Teachers can view their own classes" ON classes 
  FOR SELECT USING (teacher_id = auth.uid());

CREATE POLICY "Students can view classes they're enrolled in" ON classes 
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM enrollments 
      WHERE enrollments.class_id = id 
      AND enrollments.student_id = auth.uid()
    )
  );

-- Add policies for enrollments
CREATE POLICY "Students can view their enrollments" ON enrollments 
  FOR SELECT USING (student_id = auth.uid());

CREATE POLICY "Teachers can view enrollments for their classes" ON enrollments 
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM classes 
      WHERE classes.id = class_id 
      AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Students can enroll in classes" ON enrollments 
  FOR INSERT WITH CHECK (student_id = auth.uid());

-- Add policies for class codes
CREATE POLICY "Teachers can create class codes" ON class_codes 
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM classes 
      WHERE classes.id = class_id 
      AND classes.teacher_id = auth.uid()
    )
  );

CREATE POLICY "Anyone can view class codes" ON class_codes 
  FOR SELECT USING (true);

-- Add assignments policy for class enrollment
CREATE POLICY "Students can view assignments for classes they're enrolled in" ON assignments 
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM enrollments 
      WHERE enrollments.class_id = class_id 
      AND enrollments.student_id = auth.uid()
    )
  ); 