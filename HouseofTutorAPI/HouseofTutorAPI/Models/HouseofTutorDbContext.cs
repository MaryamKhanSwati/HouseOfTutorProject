using System;
using System.Collections.Generic;
using Microsoft.EntityFrameworkCore;

namespace HouseofTutorAPI.Models;

public partial class HouseofTutorDbContext : DbContext
{
    public HouseofTutorDbContext()
    {
    }

    public HouseofTutorDbContext(DbContextOptions<HouseofTutorDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Course> Courses { get; set; }

    public virtual DbSet<CourseCode> CourseCodes { get; set; }

    public virtual DbSet<CoursePlanSession> CoursePlanSessions { get; set; }

    public virtual DbSet<Feedback> Feedbacks { get; set; }

    public virtual DbSet<LtRoom> LtRooms { get; set; }

    public virtual DbSet<LtRoomBooking> LtRoomBookings { get; set; }

    public virtual DbSet<LtRoomSchedule> LtRoomSchedules { get; set; }

    public virtual DbSet<Payment> Payments { get; set; }

    public virtual DbSet<ProgrammingLanguage> ProgrammingLanguages { get; set; }

    public virtual DbSet<Request> Requests { get; set; }

    public virtual DbSet<RequestCoursePlan> RequestCoursePlans { get; set; }

    public virtual DbSet<RequestGroup> RequestGroups { get; set; }

    public virtual DbSet<Schedule> Schedules { get; set; }

    public virtual DbSet<Student> Students { get; set; }

    public virtual DbSet<StudentCourse> StudentCourses { get; set; }

    public virtual DbSet<StudentCourseContent> StudentCourseContents { get; set; }

    public virtual DbSet<StudentCourseFee> StudentCourseFees { get; set; }

    public virtual DbSet<StudentFriend> StudentFriends { get; set; }

    public virtual DbSet<StudentSchedule> StudentSchedules { get; set; }

    public virtual DbSet<StudyGroup> StudyGroups { get; set; }

    public virtual DbSet<StudyGroupInvitation> StudyGroupInvitations { get; set; }

    public virtual DbSet<StudyGroupMember> StudyGroupMembers { get; set; }

    public virtual DbSet<Tutor> Tutors { get; set; }

    public virtual DbSet<TutorCourse> TutorCourses { get; set; }

    public virtual DbSet<TutorCourseEvidence> TutorCourseEvidences { get; set; }

    // NEW: proper model for the Tutor_Course_Programming_Language join table
    public virtual DbSet<TutorCourseProgrammingLanguage> TutorCourseProgrammingLanguages { get; set; }

    public virtual DbSet<TutorCourseRate> TutorCourseRates { get; set; }

    public virtual DbSet<TutorPreviousTeacher> TutorPreviousTeachers { get; set; }

    //public virtual DbSet<TutorTranscript> TutorTranscripts { get; set; }

    public virtual DbSet<User> Users { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
#warning To protect potentially sensitive information in your connection string, you should move it out of source code. You can avoid scaffolding the connection string by using the Name= syntax to read it from configuration - see https://go.microsoft.com/fwlink/?linkid=2131148. For more guidance on storing connection strings, see https://go.microsoft.com/fwlink/?LinkId=723263.
        => optionsBuilder.UseSqlServer("Server=MARYUMMALIK\\SQLEXPRESS;Database=HouseofTutorDb;Trusted_Connection=True;TrustServerCertificate=True;Connect Timeout=120;");

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Course>(entity =>
        {
            entity.HasKey(e => e.CourseId).HasName("PK__Course__8F1EF7AEE1EC40A1");

            entity.ToTable("Course");

            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.AdminSetMaxHourlyRate)
                .HasColumnType("decimal(10, 2)")
                .HasColumnName("admin_set_max_hourly_rate");
            entity.Property(e => e.AdminSetMinHourlyRate)
                .HasColumnType("decimal(10, 2)")
                .HasColumnName("admin_set_min_hourly_rate");
            entity.Property(e => e.CourseTitle)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("course_title");
            entity.Property(e => e.HasLabComponent).HasColumnName("has_lab_component");
            entity.Property(e => e.StandardClassesPerWeek).HasColumnName("standard_classes_per_week");
            entity.Property(e => e.StandardDurationWeeks).HasColumnName("standard_duration_weeks");
            entity.Property(e => e.TotalStandardClasses)
                .HasComputedColumnSql("([standard_duration_weeks]*[standard_classes_per_week])", true)
                .HasColumnName("total_standard_classes");
        });

        modelBuilder.Entity<CourseCode>(entity =>
        {
            entity.HasKey(e => e.CourseCodeId).HasName("PK__Course_C__ED853DAC36348324");

            entity.ToTable("Course_Code");

            entity.HasIndex(e => e.CourseCode1, "IX_CourseCode_Code");

            entity.HasIndex(e => new { e.Institute, e.CourseCode1, e.Program }, "UQ_Course_Code").IsUnique();

            entity.Property(e => e.CourseCodeId).HasColumnName("course_code_id");
            entity.Property(e => e.CourseCode1)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("course_code");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.Description)
                .HasMaxLength(500)
                .IsUnicode(false)
                .HasColumnName("description");
            entity.Property(e => e.Institute)
                .HasMaxLength(150)
                .IsUnicode(false)
                .HasColumnName("institute");
            entity.Property(e => e.Program)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("program");

            entity.HasOne(d => d.Course).WithMany(p => p.CourseCodes)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Course_Co__cours__3D2915A8");
        });

        modelBuilder.Entity<CoursePlanSession>(entity =>
        {
            entity.HasKey(e => e.SessionId).HasName("PK__Course_P__69B13FDCC1883C16");

            entity.ToTable("Course_Plan_Session");

            entity.HasIndex(e => new { e.PlanId, e.ClassNumber }, "UQ__Course_P__35AC26BE8E856129").IsUnique();

            entity.Property(e => e.SessionId).HasColumnName("session_id");
            entity.Property(e => e.ClassDate).HasColumnName("class_date");
            entity.Property(e => e.ClassNumber).HasColumnName("class_number");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.EndTime).HasColumnName("end_time");
            entity.Property(e => e.PlanId).HasColumnName("plan_id");
            entity.Property(e => e.StartTime).HasColumnName("start_time");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Scheduled")
                .HasColumnName("status");
            entity.Property(e => e.WeekNumber).HasColumnName("week_number");

            entity.HasOne(d => d.Plan).WithMany(p => p.CoursePlanSessions)
                .HasForeignKey(d => d.PlanId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Course_Pl__plan___7EF6D905");
        });

        modelBuilder.Entity<Feedback>(entity =>
        {
            entity.HasKey(e => e.FeedbackId).HasName("PK__Feedback__7A6B2B8C44B041E7");

            entity.ToTable("Feedback");

            entity.Property(e => e.FeedbackId).HasColumnName("feedback_id");
            entity.Property(e => e.Comment)
                .HasMaxLength(255)
                .IsUnicode(false)
                .HasColumnName("comment");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.FeedbackBy)
                .HasMaxLength(20)
                .HasColumnName("feedback_by");
            entity.Property(e => e.FeedbackDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("feedback_date");
            entity.Property(e => e.Rating).HasColumnName("rating");
            entity.Property(e => e.StudentId).HasColumnName("student_id");
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

            entity.HasOne(d => d.Course).WithMany(p => p.Feedbacks)
                .HasForeignKey(d => d.CourseId)
                .HasConstraintName("FK__Feedback__course__47A6A41B");

            entity.HasOne(d => d.Student).WithMany(p => p.Feedbacks)
                .HasForeignKey(d => d.StudentId)
                .HasConstraintName("FK__Feedback__studen__45BE5BA9");

            entity.HasOne(d => d.Tutor).WithMany(p => p.Feedbacks)
                .HasForeignKey(d => d.TutorId)
                .HasConstraintName("FK__Feedback__tutor___46B27FE2");
        });

        modelBuilder.Entity<LtRoom>(entity =>
        {
            entity.HasKey(e => e.LtRoomId).HasName("PK__LT_Room__C7493DA170BA9524");

            entity.ToTable("LT_Room");

            entity.HasIndex(e => e.RoomName, "UQ__LT_Room__1B7D99CD77880B3F").IsUnique();

            entity.Property(e => e.LtRoomId).HasColumnName("lt_room_id");
            entity.Property(e => e.Capacity)
                .HasDefaultValue(3)
                .HasColumnName("capacity");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.RoomName)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("room_name");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Active")
                .HasColumnName("status");
        });

        modelBuilder.Entity<LtRoomBooking>(entity =>
        {
            entity.HasKey(e => e.LtBookingId).HasName("PK__LT_Room___4ECCAA7FF59960A5");

            entity.ToTable("LT_Room_Booking");

            entity.Property(e => e.LtBookingId).HasColumnName("lt_booking_id");
            entity.Property(e => e.ClassDate).HasColumnName("class_date");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.Day)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("day");
            entity.Property(e => e.EndTime).HasColumnName("end_time");
            entity.Property(e => e.LtRoomId).HasColumnName("lt_room_id");
            entity.Property(e => e.StartTime).HasColumnName("start_time");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Booked")
                .HasColumnName("status");
            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

            entity.HasOne(d => d.Course).WithMany(p => p.LtRoomBookings)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__LT_Room_B__cours__5E8A0973");

            entity.HasOne(d => d.LtRoom).WithMany(p => p.LtRoomBookings)
                .HasForeignKey(d => d.LtRoomId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__LT_Room_B__lt_ro__5CA1C101");

            entity.HasOne(d => d.StudyGroup).WithMany(p => p.LtRoomBookings)
                .HasForeignKey(d => d.StudyGroupId)
                .HasConstraintName("FK__LT_Room_B__study__5F7E2DAC");

            entity.HasOne(d => d.Tutor).WithMany(p => p.LtRoomBookings)
                .HasForeignKey(d => d.TutorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__LT_Room_B__tutor__5D95E53A");
        });

        modelBuilder.Entity<LtRoomSchedule>(entity =>
        {
            entity.HasKey(e => e.LtScheduleId).HasName("PK__LT_Room___6866EEFA8DAE894F");

            entity.ToTable("LT_Room_Schedule");

            entity.Property(e => e.LtScheduleId).HasColumnName("lt_schedule_id");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.Day)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("day");
            entity.Property(e => e.EndDate).HasColumnName("end_date");
            entity.Property(e => e.LtRoomId).HasColumnName("lt_room_id");
            entity.Property(e => e.StartDate).HasColumnName("start_date");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Available")
                .HasColumnName("status");
            entity.Property(e => e.Time)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("time");

            entity.HasOne(d => d.LtRoom).WithMany(p => p.LtRoomSchedules)
                .HasForeignKey(d => d.LtRoomId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__LT_Room_S__lt_ro__797309D9");
        });

        modelBuilder.Entity<Payment>(entity =>
        {
            entity.HasKey(e => e.PaymentId).HasName("PK__Payment__ED1FC9EA0CD18477");

            entity.ToTable("Payment");

            entity.Property(e => e.PaymentId).HasColumnName("payment_id");
            entity.Property(e => e.Amount)
                .HasColumnType("decimal(10, 2)")
                .HasColumnName("amount");
            entity.Property(e => e.FeeId).HasColumnName("fee_id");
            entity.Property(e => e.ParentStatus)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("parent_status");
            entity.Property(e => e.PaymentDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("payment_date");
            entity.Property(e => e.PaymentType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("payment_type");
            entity.Property(e => e.Remarks)
                .HasMaxLength(200)
                .IsUnicode(false)
                .HasColumnName("remarks");
            entity.Property(e => e.TutorStatus)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("tutor_status");

            entity.HasOne(d => d.Fee).WithMany(p => p.Payments)
                .HasForeignKey(d => d.FeeId)
                .HasConstraintName("FK__Payment__fee_id__40F9A68C");
        });

        modelBuilder.Entity<ProgrammingLanguage>(entity =>
        {
            entity.HasKey(e => e.LanguageId).HasName("PK__Programm__804CF6B32B0FDBDA");

            entity.ToTable("Programming_Language");

            entity.HasIndex(e => e.LanguageName, "UQ__Programm__9CE8238307DF55FE").IsUnique();

            entity.Property(e => e.LanguageId).HasColumnName("language_id");
            entity.Property(e => e.LanguageName)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("language_name");
            entity.Property(e => e.Status)
                .HasDefaultValue(true)
                .HasColumnName("status");
        });

        modelBuilder.Entity<Request>(entity =>
        {
            entity.HasKey(e => e.RequestId).HasName("PK__Request__18D3B90F8AAF1A59");

            entity.ToTable("Request");

            entity.Property(e => e.RequestId).HasColumnName("request_id");
            entity.Property(e => e.ClassDate).HasColumnName("class_date");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.Day)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("day");
            entity.Property(e => e.LearningDuration).HasColumnName("learning_duration");
            entity.Property(e => e.LearningDurationUnit)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("learning_duration_unit");
            entity.Property(e => e.LearningMode)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("learning_mode");
            entity.Property(e => e.ParentRequestId).HasColumnName("parent_request_id");
            entity.Property(e => e.RequestDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("request_date");
            entity.Property(e => e.RequestGroupId).HasColumnName("request_group_id");
            entity.Property(e => e.RequestType)
                .HasMaxLength(50)
                .IsUnicode(false)
                .HasColumnName("request_type");
            entity.Property(e => e.ResponseDeadline)
                .HasColumnType("datetime")
                .HasColumnName("response_deadline");
            entity.Property(e => e.Status)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.StudentId).HasColumnName("student_id");
            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");
            entity.Property(e => e.Time)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
            entity.Property(e => e.TutorSequence).HasColumnName("tutor_sequence");

            entity.HasOne(d => d.Course).WithMany(p => p.Requests)
                .HasForeignKey(d => d.CourseId)
                .HasConstraintName("FK__Request__course___078C1F06");

            entity.HasOne(d => d.RequestGroup).WithMany(p => p.Requests)
                .HasForeignKey(d => d.RequestGroupId)
                .HasConstraintName("FK__Request__request__04AFB25B");

            entity.HasOne(d => d.Student).WithMany(p => p.Requests)
                .HasForeignKey(d => d.StudentId)
                .HasConstraintName("FK__Request__student__05A3D694");

            entity.HasOne(d => d.StudyGroup).WithMany(p => p.Requests)
                .HasForeignKey(d => d.StudyGroupId)
                .HasConstraintName("FK__Request__study_g__0880433F");

            entity.HasOne(d => d.Tutor).WithMany(p => p.Requests)
                .HasForeignKey(d => d.TutorId)
                .HasConstraintName("FK__Request__tutor_i__0697FACD");
        });

        modelBuilder.Entity<RequestCoursePlan>(entity =>
        {
            entity.HasKey(e => e.PlanId).HasName("PK__Request___BE9F8F1D504F6EA2");

            entity.ToTable("Request_Course_Plan");

            entity.HasIndex(e => e.RequestGroupId, "UQ__Request___30D47C28EE664CC0").IsUnique();

            entity.Property(e => e.PlanId).HasColumnName("plan_id");
            entity.Property(e => e.ApprovedByTutorId).HasColumnName("approved_by_tutor_id");
            entity.Property(e => e.ApprovedDate)
                .HasColumnType("datetime")
                .HasColumnName("approved_date");
            entity.Property(e => e.ClassDurationMinutes).HasColumnName("class_duration_minutes");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.OriginalClassesPerWeek).HasColumnName("original_classes_per_week");
            entity.Property(e => e.OriginalDurationWeeks).HasColumnName("original_duration_weeks");
            entity.Property(e => e.PlanType)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("plan_type");
            entity.Property(e => e.RequestGroupId).HasColumnName("request_group_id");
            entity.Property(e => e.RequestedClassesPerWeek).HasColumnName("requested_classes_per_week");
            entity.Property(e => e.RequestedDurationWeeks).HasColumnName("requested_duration_weeks");
            entity.Property(e => e.StartDate).HasColumnName("start_date");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Pending")
                .HasColumnName("status");
            entity.Property(e => e.TargetEndDate).HasColumnName("target_end_date");
            entity.Property(e => e.TotalClasses).HasColumnName("total_classes");
            entity.Property(e => e.TutorRemarks)
                .HasMaxLength(500)
                .IsUnicode(false)
                .HasColumnName("tutor_remarks");

            entity.HasOne(d => d.ApprovedByTutor).WithMany(p => p.RequestCoursePlans)
                .HasForeignKey(d => d.ApprovedByTutorId)
                .HasConstraintName("FK__Request_C__appro__6DCC4D03");

            entity.HasOne(d => d.RequestGroup).WithOne(p => p.RequestCoursePlan)
                .HasForeignKey<RequestCoursePlan>(d => d.RequestGroupId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Request_C__reque__6EC0713C");
        });

        modelBuilder.Entity<RequestGroup>(entity =>
        {
            entity.HasKey(e => e.RequestGroupId).HasName("PK__Request___30D47C29D1CC79D2");

            entity.ToTable("Request_Group");

            entity.Property(e => e.RequestGroupId).HasColumnName("request_group_id");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.CurrentRequestId).HasColumnName("current_request_id");
            entity.Property(e => e.Status)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasColumnName("status");
            entity.Property(e => e.StudentId).HasColumnName("student_id");

            entity.HasOne(d => d.Course).WithMany(p => p.RequestGroups)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Request_G__cours__1DB06A4F");

            entity.HasOne(d => d.Student).WithMany(p => p.RequestGroups)
                .HasForeignKey(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Request_G__stude__1CBC4616");
        });

        modelBuilder.Entity<Schedule>(entity =>
        {
            entity.HasKey(e => e.ScheduleId).HasName("PK__Schedule__C46A8A6FD9635445");

            entity.ToTable("Schedule");

            entity.Property(e => e.ScheduleId).HasColumnName("schedule_id");
            entity.Property(e => e.Day)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("day");
            entity.Property(e => e.EndDate).HasColumnName("end_date");
            entity.Property(e => e.StartDate).HasColumnName("start_date");
            entity.Property(e => e.Time)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("time");
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
            entity.Property(e => e.Type)
                .HasMaxLength(50)
                .IsUnicode(false);

            entity.HasOne(d => d.Tutor).WithMany(p => p.Schedules)
                .HasForeignKey(d => d.TutorId)
                .HasConstraintName("FK__Schedule__tutor___7C4F7684");
        });

        modelBuilder.Entity<Student>(entity =>
        {
            entity.HasKey(e => e.StudentId).HasName("PK__Student__2A33069A61A82BB6");

            entity.ToTable("Student");

            entity.Property(e => e.StudentId).HasColumnName("student_id");
            entity.Property(e => e.FatherCnic)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("Father_Cnic");
            entity.Property(e => e.FeeResponsibility)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("fee_responsibility");
            entity.Property(e => e.Location)
                .IsUnicode(false)
                .HasColumnName("location");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("status");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.Students)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__Student__user_id__73BA3083");
        });

        modelBuilder.Entity<StudentCourse>(entity =>
        {
            entity.HasKey(e => new { e.StudentId, e.CourseId }).HasName("PK__Student___D2C2E9E02F085B24");

            entity.ToTable("Student_Course");

            entity.Property(e => e.StudentId).HasColumnName("student_id");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.Grade)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("grade");
            entity.Property(e => e.PreferredLanguageId).HasColumnName("preferred_language_id");

            entity.HasOne(d => d.Course).WithMany(p => p.StudentCourses)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_C__cours__0C85DE4D");

            entity.HasOne(d => d.PreferredLanguage).WithMany(p => p.StudentCourses)
                .HasForeignKey(d => d.PreferredLanguageId)
                .HasConstraintName("FK__Student_C__prefe__0D7A0286");

            entity.HasOne(d => d.Student).WithMany(p => p.StudentCourses)
                .HasForeignKey(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_C__stude__0B91BA14");
        });

        modelBuilder.Entity<StudentCourseContent>(entity =>
        {
            entity.HasKey(e => e.ContentId).HasName("PK__Student___655FE51046CD6DCA");

            entity.ToTable("Student_Course_Content");

            entity.Property(e => e.ContentId).HasColumnName("content_id");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.Description)
                .HasMaxLength(500)
                .IsUnicode(false)
                .HasColumnName("description");
            entity.Property(e => e.FileName)
                .HasMaxLength(255)
                .IsUnicode(false)
                .HasColumnName("file_name");
            entity.Property(e => e.FilePath)
                .HasMaxLength(500)
                .IsUnicode(false)
                .HasColumnName("file_path");
            entity.Property(e => e.StudentId).HasColumnName("student_id");
            entity.Property(e => e.Title)
                .HasMaxLength(150)
                .IsUnicode(false)
                .HasColumnName("title");
            entity.Property(e => e.UploadedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("uploaded_date");

            entity.HasOne(d => d.Course).WithMany(p => p.StudentCourseContents)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_C__cours__236943A5");

            entity.HasOne(d => d.Student).WithMany(p => p.StudentCourseContents)
                .HasForeignKey(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_C__stude__22751F6C");
        });

        modelBuilder.Entity<StudentCourseFee>(entity =>
        {
            entity.HasKey(e => e.FeeId).HasName("PK__Student___A19C8AFB2A507020");

            entity.ToTable("Student_Course_Fee");

            entity.HasIndex(e => new { e.StudentId, e.TutorId, e.CourseId }, "UQ__Student___80B1FDBCE370277E").IsUnique();

            entity.Property(e => e.FeeId).HasColumnName("fee_id");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.FeeResponsibility)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Parent")
                .HasColumnName("fee_responsibility");
            entity.Property(e => e.StudentId).HasColumnName("student_id");
            entity.Property(e => e.TotalFee)
                .HasColumnType("decimal(10, 2)")
                .HasColumnName("total_fee");
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

            entity.HasOne(d => d.Course).WithMany(p => p.StudentCourseFees)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_C__cours__18EBB532");

            entity.HasOne(d => d.Student).WithMany(p => p.StudentCourseFees)
                .HasForeignKey(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_C__stude__17036CC0");

            entity.HasOne(d => d.Tutor).WithMany(p => p.StudentCourseFees)
                .HasForeignKey(d => d.TutorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_C__tutor__17F790F9");
        });

        modelBuilder.Entity<StudentFriend>(entity =>
        {
            entity.HasKey(e => e.FriendshipId).HasName("PK__Student___BC802BCF95974579");

            entity.ToTable("Student_Friend");

            entity.Property(e => e.FriendshipId).HasColumnName("friendship_id");
            entity.Property(e => e.AcceptedDate)
                .HasColumnType("datetime")
                .HasColumnName("accepted_date");
            entity.Property(e => e.FriendStudentId).HasColumnName("friend_student_id");
            entity.Property(e => e.RequestedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("requested_date");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Pending")
                .HasColumnName("status");
            entity.Property(e => e.StudentId).HasColumnName("student_id");

            entity.HasOne(d => d.FriendStudent).WithMany(p => p.StudentFriendFriendStudents)
                .HasForeignKey(d => d.FriendStudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_F__frien__2A164134");

            entity.HasOne(d => d.Student).WithMany(p => p.StudentFriendStudents)
                .HasForeignKey(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Student_F__stude__29221CFB");
        });

        modelBuilder.Entity<StudentSchedule>(entity =>
        {
            entity.HasKey(e => e.ScheduleId).HasName("PK__Student___C46A8A6F22A72894");

            entity.ToTable("Student_Schedule");

            entity.Property(e => e.ScheduleId).HasColumnName("schedule_id");
            entity.Property(e => e.Day)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("day");
            entity.Property(e => e.EndDate).HasColumnName("end_date");
            entity.Property(e => e.StartDate).HasColumnName("start_date");
            entity.Property(e => e.StudentId).HasColumnName("student_id");
            entity.Property(e => e.Time)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("time");
            entity.Property(e => e.Type)
                .HasMaxLength(50)
                .IsUnicode(false);

            entity.HasOne(d => d.Student).WithMany(p => p.StudentSchedules)
                .HasForeignKey(d => d.StudentId)
                .HasConstraintName("FK__Student_S__stude__00200768");
        });

        modelBuilder.Entity<StudyGroup>(entity =>
        {
            entity.HasKey(e => e.StudyGroupId).HasName("PK__Study_Gr__2471BA042829383E");

            entity.ToTable("Study_Group");

            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.CreatedByStudentId).HasColumnName("created_by_student_id");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.GroupName)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("group_name");
            entity.Property(e => e.MaxStudents)
                .HasDefaultValue(10)
                .HasColumnName("max_students");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Open")
                .HasColumnName("status");
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

            entity.HasOne(d => d.Course).WithMany(p => p.StudyGroups)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Study_Gro__cours__32AB8735");

            entity.HasOne(d => d.CreatedByStudent).WithMany(p => p.StudyGroups)
                .HasForeignKey(d => d.CreatedByStudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Study_Gro__creat__31B762FC");

            entity.HasOne(d => d.Tutor).WithMany(p => p.StudyGroups)
                .HasForeignKey(d => d.TutorId)
                .HasConstraintName("FK__Study_Gro__tutor__339FAB6E");
        });

        modelBuilder.Entity<StudyGroupInvitation>(entity =>
        {
            entity.HasKey(e => e.InvitationId).HasName("PK__Study_Gr__94B74D7C7BEB83B2");

            entity.ToTable("Study_Group_Invitation");

            entity.Property(e => e.InvitationId).HasColumnName("invitation_id");
            entity.Property(e => e.InvitationDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("invitation_date");
            entity.Property(e => e.InvitedByStudentId).HasColumnName("invited_by_student_id");
            entity.Property(e => e.InvitedStudentId).HasColumnName("invited_student_id");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Pending")
                .HasColumnName("status");
            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");

            entity.HasOne(d => d.InvitedByStudent).WithMany(p => p.StudyGroupInvitationInvitedByStudents)
                .HasForeignKey(d => d.InvitedByStudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Study_Gro__invit__56E8E7AB");

            entity.HasOne(d => d.InvitedStudent).WithMany(p => p.StudyGroupInvitationInvitedStudents)
                .HasForeignKey(d => d.InvitedStudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Study_Gro__invit__55F4C372");

            entity.HasOne(d => d.StudyGroup).WithMany(p => p.StudyGroupInvitations)
                .HasForeignKey(d => d.StudyGroupId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Study_Gro__study__55009F39");
        });

        modelBuilder.Entity<StudyGroupMember>(entity =>
        {
            entity.HasKey(e => e.GroupMemberId).HasName("PK__Study_Gr__F3C66B8C751E50DE");

            entity.ToTable("Study_Group_Member");

            entity.HasIndex(e => new { e.StudyGroupId, e.StudentId }, "UQ__Study_Gr__96D28A6C7A9A0199").IsUnique();

            entity.Property(e => e.GroupMemberId).HasColumnName("group_member_id");
            entity.Property(e => e.JoinedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("joined_date");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Active")
                .HasColumnName("status");
            entity.Property(e => e.StudentId).HasColumnName("student_id");
            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");

            entity.HasOne(d => d.Student).WithMany(p => p.StudyGroupMembers)
                .HasForeignKey(d => d.StudentId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Study_Gro__stude__4F47C5E3");

            entity.HasOne(d => d.StudyGroup).WithMany(p => p.StudyGroupMembers)
                .HasForeignKey(d => d.StudyGroupId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Study_Gro__study__4E53A1AA");
        });

        modelBuilder.Entity<Tutor>(entity =>
        {
            entity.HasKey(e => e.TutorId).HasName("PK__Tutor__50DE5D01BF10C07F");

            entity.ToTable("Tutor");

            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
            entity.Property(e => e.Experience).HasColumnName("experience");
            entity.Property(e => e.Location)
                .IsUnicode(false)
                .HasColumnName("location");
            entity.Property(e => e.Qualification)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("qualification");
            entity.Property(e => e.Radius).HasColumnName("radius");
            entity.Property(e => e.Status)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("status");
            entity.Property(e => e.TeachingMode)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("teaching_mode");
            entity.Property(e => e.UserId).HasColumnName("user_id");

            entity.HasOne(d => d.User).WithMany(p => p.Tutors)
                .HasForeignKey(d => d.UserId)
                .HasConstraintName("FK__Tutor__user_id__70DDC3D8");
        });

        modelBuilder.Entity<TutorCourse>(entity =>
        {
            entity.HasKey(e => new { e.TutorId, e.CourseId }).HasName("PK__Tutor_Co__A82FB27B7645D8F0");

            entity.ToTable("Tutor_Course");

            entity.HasIndex(e => e.GradeVerificationStatus, "IX_TutorCourse_Verification");

            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.CompletedDate)
                .HasColumnType("datetime")
                .HasColumnName("completed_date");
            entity.Property(e => e.Grade)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasColumnName("grade");
            entity.Property(e => e.GradeVerificationStatus)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Pending", "DF_TutorCourse_Verification")
                .HasColumnName("grade_verification_status");
            entity.Property(e => e.Institute)
                .HasMaxLength(150)
                .IsUnicode(false)
                .HasColumnName("institute");
            entity.Property(e => e.IsCompleted).HasColumnName("is_completed");
            entity.Property(e => e.LabCompleted).HasColumnName("lab_completed");
            entity.Property(e => e.VerificationRemarks)
                .HasMaxLength(500)
                .IsUnicode(false)
                .HasColumnName("verification_remarks");
            entity.Property(e => e.VerifiedBy).HasColumnName("verified_by");
            entity.Property(e => e.VerifiedDate)
                .HasColumnType("datetime")
                .HasColumnName("verified_date");

            entity.HasOne(d => d.Course).WithMany(p => p.TutorCourses)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Tutor_Cou__cours__06CD04F7");

            entity.HasOne(d => d.Tutor).WithMany(p => p.TutorCourses)
                .HasForeignKey(d => d.TutorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Tutor_Cou__tutor__05D8E0BE");

            entity.HasOne(d => d.VerifiedByNavigation).WithMany(p => p.TutorCourses)
                .HasForeignKey(d => d.VerifiedBy)
                .HasConstraintName("FK__Tutor_Cou__verif__07C12930");

            // UPDATED: join table now uses the explicit TutorCourseProgrammingLanguage model
            // (same table, same columns, same constraint names - no DB change needed)
            entity.HasMany(d => d.Languages).WithMany(p => p.TutorCourses)
                .UsingEntity<TutorCourseProgrammingLanguage>(
                    r => r.HasOne(x => x.Language)
                        .WithMany()
                        .HasForeignKey(x => x.LanguageId)
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK__Tutor_Cou__langu__793DFFAF"),
                    l => l.HasOne(x => x.TutorCourse)
                        .WithMany()
                        .HasForeignKey(x => new { x.TutorId, x.CourseId })
                        .OnDelete(DeleteBehavior.ClientSetNull)
                        .HasConstraintName("FK__Tutor_Course_Pro__7849DB76"),
                    j =>
                    {
                        j.HasKey(x => new { x.TutorId, x.CourseId, x.LanguageId })
                            .HasName("PK__Tutor_Co__1AAFFE8D1BF9D2EB");

                        j.ToTable("Tutor_Course_Programming_Language");

                        j.Property(x => x.TutorId).HasColumnName("tutor_id");
                        j.Property(x => x.CourseId).HasColumnName("course_id");
                        j.Property(x => x.LanguageId).HasColumnName("language_id");
                    });
        });

        modelBuilder.Entity<TutorCourseEvidence>(entity =>
        {
            entity.HasKey(e => e.EvidenceId).HasName("PK__Tutor_Co__C59A788E1D996C98");

            entity.ToTable("Tutor_Course_Evidence");

            entity.HasIndex(e => e.VerificationStatus, "IX_CourseEvidence_Status");

            entity.Property(e => e.EvidenceId).HasColumnName("evidence_id");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.EvidenceType)
                .HasMaxLength(30)
                .IsUnicode(false)
                .HasColumnName("evidence_type");
            entity.Property(e => e.FileName)
                .HasMaxLength(255)
                .IsUnicode(false)
                .HasColumnName("file_name");
            entity.Property(e => e.FilePath)
                .HasMaxLength(500)
                .IsUnicode(false)
                .HasColumnName("file_path");
            entity.Property(e => e.Remarks)
                .HasMaxLength(500)
                .IsUnicode(false)
                .HasColumnName("remarks");
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
            entity.Property(e => e.UploadedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("uploaded_date");
            entity.Property(e => e.VerificationStatus)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasDefaultValue("Pending")
                .HasColumnName("verification_status");
            entity.Property(e => e.VerifiedBy).HasColumnName("verified_by");
            entity.Property(e => e.VerifiedDate)
                .HasColumnType("datetime")
                .HasColumnName("verified_date");

            entity.HasOne(d => d.VerifiedByNavigation).WithMany(p => p.TutorCourseEvidences)
                .HasForeignKey(d => d.VerifiedBy)
                .HasConstraintName("FK__Tutor_Cou__verif__662B2B3B");

            entity.HasOne(d => d.TutorCourse).WithMany(p => p.TutorCourseEvidences)
                .HasForeignKey(d => new { d.TutorId, d.CourseId })
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Tutor_Course_Evi__65370702");
        });

        modelBuilder.Entity<TutorCourseRate>(entity =>
        {
            entity.HasKey(e => e.RateId).HasName("PK__Tutor_Co__75920B4294E8F807");

            entity.ToTable("Tutor_Course_Rate");

            entity.Property(e => e.RateId).HasColumnName("rate_id");
            entity.Property(e => e.AdminSetMaxHourlyRate)
                .HasColumnType("decimal(10, 2)")
                .HasColumnName("admin_set_max_hourly_rate");
            entity.Property(e => e.AdminSetMinHourlyRate)
                .HasColumnType("decimal(10, 2)")
                .HasColumnName("admin_set_min_hourly_rate");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.HourlyRate)
                .HasColumnType("decimal(10, 2)")
                .HasColumnName("hourly_rate");
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

            entity.HasOne(d => d.Course).WithMany(p => p.TutorCourseRates)
                .HasForeignKey(d => d.CourseId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Tutor_Cou__cours__114A936A");

            entity.HasOne(d => d.Tutor).WithMany(p => p.TutorCourseRates)
                .HasForeignKey(d => d.TutorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Tutor_Cou__tutor__10566F31");
        });

        modelBuilder.Entity<TutorPreviousTeacher>(entity =>
        {
            entity.HasKey(e => e.PreviousTeacherId).HasName("PK__Tutor_Pr__E6BA1949DF014DB8");

            entity.ToTable("Tutor_Previous_Teacher");

            entity.HasIndex(e => e.TeacherName, "IX_PreviousTeacher_Name");

            entity.Property(e => e.PreviousTeacherId).HasColumnName("previous_teacher_id");
            entity.Property(e => e.CourseId).HasColumnName("course_id");
            entity.Property(e => e.CreatedDate)
                .HasDefaultValueSql("(getdate())")
                .HasColumnType("datetime")
                .HasColumnName("created_date");
            entity.Property(e => e.Description)
                .HasMaxLength(500)
                .IsUnicode(false)
                .HasColumnName("description");
            entity.Property(e => e.Institute)
                .HasMaxLength(150)
                .IsUnicode(false)
                .HasColumnName("institute");
            entity.Property(e => e.StudyYear).HasColumnName("study_year");
            entity.Property(e => e.TeacherName)
                .HasMaxLength(150)
                .IsUnicode(false)
                .HasColumnName("teacher_name");
            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

            entity.HasOne(d => d.Course).WithMany(p => p.TutorPreviousTeachers)
                .HasForeignKey(d => d.CourseId)
                .HasConstraintName("FK__Tutor_Pre__cours__395884C4");

            entity.HasOne(d => d.Tutor).WithMany(p => p.TutorPreviousTeachers)
                .HasForeignKey(d => d.TutorId)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK__Tutor_Pre__tutor__3864608B");
        });

        

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.UserId).HasName("PK__Users__B9BE370FA914C184");

            entity.HasIndex(e => e.Email, "UQ__Users__AB6E616461D60F0F").IsUnique();

            entity.Property(e => e.UserId).HasColumnName("user_id");
            entity.Property(e => e.Cnic)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("cnic");
            entity.Property(e => e.Email)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("email");
            entity.Property(e => e.FullName)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("full_name");
            entity.Property(e => e.Password)
                .HasMaxLength(100)
                .IsUnicode(false)
                .HasColumnName("password");
            entity.Property(e => e.Phone)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("phone");
            entity.Property(e => e.Role)
                .HasMaxLength(20)
                .IsUnicode(false)
                .HasColumnName("role");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}





































//using System;
//using System.Collections.Generic;
//using Microsoft.EntityFrameworkCore;

//namespace HouseofTutorAPI.Models;

//public partial class HouseofTutorDbContext : DbContext
//{
//    public HouseofTutorDbContext()
//    {
//    }

//    public HouseofTutorDbContext(DbContextOptions<HouseofTutorDbContext> options)
//        : base(options)
//    {
//    }

//    public virtual DbSet<Course> Courses { get; set; }

//    public virtual DbSet<CourseCode> CourseCodes { get; set; }

//    public virtual DbSet<CoursePlanSession> CoursePlanSessions { get; set; }

//    public virtual DbSet<Feedback> Feedbacks { get; set; }

//    public virtual DbSet<LtRoom> LtRooms { get; set; }

//    public virtual DbSet<LtRoomBooking> LtRoomBookings { get; set; }

//    public virtual DbSet<LtRoomSchedule> LtRoomSchedules { get; set; }

//    public virtual DbSet<Payment> Payments { get; set; }

//    public virtual DbSet<ProgrammingLanguage> ProgrammingLanguages { get; set; }

//    public virtual DbSet<Request> Requests { get; set; }

//    public virtual DbSet<RequestCoursePlan> RequestCoursePlans { get; set; }

//    public virtual DbSet<RequestGroup> RequestGroups { get; set; }

//    public virtual DbSet<Schedule> Schedules { get; set; }

//    public virtual DbSet<Student> Students { get; set; }

//    public virtual DbSet<StudentCourse> StudentCourses { get; set; }

//    public virtual DbSet<StudentCourseContent> StudentCourseContents { get; set; }

//    public virtual DbSet<StudentCourseFee> StudentCourseFees { get; set; }

//    public virtual DbSet<StudentFriend> StudentFriends { get; set; }

//    public virtual DbSet<StudentSchedule> StudentSchedules { get; set; }

//    public virtual DbSet<StudyGroup> StudyGroups { get; set; }

//    public virtual DbSet<StudyGroupInvitation> StudyGroupInvitations { get; set; }

//    public virtual DbSet<StudyGroupMember> StudyGroupMembers { get; set; }

//    public virtual DbSet<Tutor> Tutors { get; set; }

//    public virtual DbSet<TutorCourse> TutorCourses { get; set; }

//    public virtual DbSet<TutorCourseEvidence> TutorCourseEvidences { get; set; }

//    public virtual DbSet<TutorCourseRate> TutorCourseRates { get; set; }

//    public virtual DbSet<TutorPreviousTeacher> TutorPreviousTeachers { get; set; }

//    public virtual DbSet<TutorTranscript> TutorTranscripts { get; set; }

//    public virtual DbSet<User> Users { get; set; }
//    public object TutorCourseProgrammingLanguages { get; set; }

//    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
//#warning To protect potentially sensitive information in your connection string, you should move it out of source code. You can avoid scaffolding the connection string by using the Name= syntax to read it from configuration - see https://go.microsoft.com/fwlink/?linkid=2131148. For more guidance on storing connection strings, see https://go.microsoft.com/fwlink/?LinkId=723263.
//        => optionsBuilder.UseSqlServer("Server=MARYUMMALIK\\SQLEXPRESS;Database=HouseofTutorDb;Trusted_Connection=True;TrustServerCertificate=True;Connect Timeout=120;");

//    protected override void OnModelCreating(ModelBuilder modelBuilder)
//    {
//        modelBuilder.Entity<Course>(entity =>
//        {
//            entity.HasKey(e => e.CourseId).HasName("PK__Course__8F1EF7AEE1EC40A1");

//            entity.ToTable("Course");

//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.AdminSetMaxHourlyRate)
//                .HasColumnType("decimal(10, 2)")
//                .HasColumnName("admin_set_max_hourly_rate");
//            entity.Property(e => e.AdminSetMinHourlyRate)
//                .HasColumnType("decimal(10, 2)")
//                .HasColumnName("admin_set_min_hourly_rate");
//            entity.Property(e => e.CourseTitle)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("course_title");
//            entity.Property(e => e.HasLabComponent).HasColumnName("has_lab_component");
//            entity.Property(e => e.StandardClassesPerWeek).HasColumnName("standard_classes_per_week");
//            entity.Property(e => e.StandardDurationWeeks).HasColumnName("standard_duration_weeks");
//            entity.Property(e => e.TotalStandardClasses)
//                .HasComputedColumnSql("([standard_duration_weeks]*[standard_classes_per_week])", true)
//                .HasColumnName("total_standard_classes");
//        });

//        modelBuilder.Entity<CourseCode>(entity =>
//        {
//            entity.HasKey(e => e.CourseCodeId).HasName("PK__Course_C__ED853DAC36348324");

//            entity.ToTable("Course_Code");

//            entity.HasIndex(e => e.CourseCode1, "IX_CourseCode_Code");

//            entity.HasIndex(e => new { e.Institute, e.CourseCode1, e.Program }, "UQ_Course_Code").IsUnique();

//            entity.Property(e => e.CourseCodeId).HasColumnName("course_code_id");
//            entity.Property(e => e.CourseCode1)
//                .HasMaxLength(50)
//                .IsUnicode(false)
//                .HasColumnName("course_code");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.Description)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("description");
//            entity.Property(e => e.Institute)
//                .HasMaxLength(150)
//                .IsUnicode(false)
//                .HasColumnName("institute");
//            entity.Property(e => e.Program)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("program");

//            entity.HasOne(d => d.Course).WithMany(p => p.CourseCodes)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Course_Co__cours__3D2915A8");
//        });

//        modelBuilder.Entity<CoursePlanSession>(entity =>
//        {
//            entity.HasKey(e => e.SessionId).HasName("PK__Course_P__69B13FDCC1883C16");

//            entity.ToTable("Course_Plan_Session");

//            entity.HasIndex(e => new { e.PlanId, e.ClassNumber }, "UQ__Course_P__35AC26BE8E856129").IsUnique();

//            entity.Property(e => e.SessionId).HasColumnName("session_id");
//            entity.Property(e => e.ClassDate).HasColumnName("class_date");
//            entity.Property(e => e.ClassNumber).HasColumnName("class_number");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.EndTime).HasColumnName("end_time");
//            entity.Property(e => e.PlanId).HasColumnName("plan_id");
//            entity.Property(e => e.StartTime).HasColumnName("start_time");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Scheduled")
//                .HasColumnName("status");
//            entity.Property(e => e.WeekNumber).HasColumnName("week_number");

//            entity.HasOne(d => d.Plan).WithMany(p => p.CoursePlanSessions)
//                .HasForeignKey(d => d.PlanId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Course_Pl__plan___7EF6D905");
//        });

//        modelBuilder.Entity<Feedback>(entity =>
//        {
//            entity.HasKey(e => e.FeedbackId).HasName("PK__Feedback__7A6B2B8C44B041E7");

//            entity.ToTable("Feedback");

//            entity.Property(e => e.FeedbackId).HasColumnName("feedback_id");
//            entity.Property(e => e.Comment)
//                .HasMaxLength(255)
//                .IsUnicode(false)
//                .HasColumnName("comment");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.FeedbackBy)
//                .HasMaxLength(20)
//                .HasColumnName("feedback_by");
//            entity.Property(e => e.FeedbackDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("feedback_date");
//            entity.Property(e => e.Rating).HasColumnName("rating");
//            entity.Property(e => e.StudentId).HasColumnName("student_id");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

//            entity.HasOne(d => d.Course).WithMany(p => p.Feedbacks)
//                .HasForeignKey(d => d.CourseId)
//                .HasConstraintName("FK__Feedback__course__47A6A41B");

//            entity.HasOne(d => d.Student).WithMany(p => p.Feedbacks)
//                .HasForeignKey(d => d.StudentId)
//                .HasConstraintName("FK__Feedback__studen__45BE5BA9");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.Feedbacks)
//                .HasForeignKey(d => d.TutorId)
//                .HasConstraintName("FK__Feedback__tutor___46B27FE2");
//        });

//        modelBuilder.Entity<LtRoom>(entity =>
//        {
//            entity.HasKey(e => e.LtRoomId).HasName("PK__LT_Room__C7493DA170BA9524");

//            entity.ToTable("LT_Room");

//            entity.HasIndex(e => e.RoomName, "UQ__LT_Room__1B7D99CD77880B3F").IsUnique();

//            entity.Property(e => e.LtRoomId).HasColumnName("lt_room_id");
//            entity.Property(e => e.Capacity)
//                .HasDefaultValue(3)
//                .HasColumnName("capacity");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.RoomName)
//                .HasMaxLength(50)
//                .IsUnicode(false)
//                .HasColumnName("room_name");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Active")
//                .HasColumnName("status");
//        });

//        modelBuilder.Entity<LtRoomBooking>(entity =>
//        {
//            entity.HasKey(e => e.LtBookingId).HasName("PK__LT_Room___4ECCAA7FF59960A5");

//            entity.ToTable("LT_Room_Booking");

//            entity.Property(e => e.LtBookingId).HasColumnName("lt_booking_id");
//            entity.Property(e => e.ClassDate).HasColumnName("class_date");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.Day)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("day");
//            entity.Property(e => e.EndTime).HasColumnName("end_time");
//            entity.Property(e => e.LtRoomId).HasColumnName("lt_room_id");
//            entity.Property(e => e.StartTime).HasColumnName("start_time");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Booked")
//                .HasColumnName("status");
//            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

//            entity.HasOne(d => d.Course).WithMany(p => p.LtRoomBookings)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__LT_Room_B__cours__5E8A0973");

//            entity.HasOne(d => d.LtRoom).WithMany(p => p.LtRoomBookings)
//                .HasForeignKey(d => d.LtRoomId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__LT_Room_B__lt_ro__5CA1C101");

//            entity.HasOne(d => d.StudyGroup).WithMany(p => p.LtRoomBookings)
//                .HasForeignKey(d => d.StudyGroupId)
//                .HasConstraintName("FK__LT_Room_B__study__5F7E2DAC");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.LtRoomBookings)
//                .HasForeignKey(d => d.TutorId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__LT_Room_B__tutor__5D95E53A");
//        });

//        modelBuilder.Entity<LtRoomSchedule>(entity =>
//        {
//            entity.HasKey(e => e.LtScheduleId).HasName("PK__LT_Room___6866EEFA8DAE894F");

//            entity.ToTable("LT_Room_Schedule");

//            entity.Property(e => e.LtScheduleId).HasColumnName("lt_schedule_id");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.Day)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("day");
//            entity.Property(e => e.EndDate).HasColumnName("end_date");
//            entity.Property(e => e.LtRoomId).HasColumnName("lt_room_id");
//            entity.Property(e => e.StartDate).HasColumnName("start_date");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Available")
//                .HasColumnName("status");
//            entity.Property(e => e.Time)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("time");

//            entity.HasOne(d => d.LtRoom).WithMany(p => p.LtRoomSchedules)
//                .HasForeignKey(d => d.LtRoomId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__LT_Room_S__lt_ro__797309D9");
//        });

//        modelBuilder.Entity<Payment>(entity =>
//        {
//            entity.HasKey(e => e.PaymentId).HasName("PK__Payment__ED1FC9EA0CD18477");

//            entity.ToTable("Payment");

//            entity.Property(e => e.PaymentId).HasColumnName("payment_id");
//            entity.Property(e => e.Amount)
//                .HasColumnType("decimal(10, 2)")
//                .HasColumnName("amount");
//            entity.Property(e => e.FeeId).HasColumnName("fee_id");
//            entity.Property(e => e.ParentStatus)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("parent_status");
//            entity.Property(e => e.PaymentDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("payment_date");
//            entity.Property(e => e.PaymentType)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("payment_type");
//            entity.Property(e => e.Remarks)
//                .HasMaxLength(200)
//                .IsUnicode(false)
//                .HasColumnName("remarks");
//            entity.Property(e => e.TutorStatus)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("tutor_status");

//            entity.HasOne(d => d.Fee).WithMany(p => p.Payments)
//                .HasForeignKey(d => d.FeeId)
//                .HasConstraintName("FK__Payment__fee_id__40F9A68C");
//        });

//        modelBuilder.Entity<ProgrammingLanguage>(entity =>
//        {
//            entity.HasKey(e => e.LanguageId).HasName("PK__Programm__804CF6B32B0FDBDA");

//            entity.ToTable("Programming_Language");

//            entity.HasIndex(e => e.LanguageName, "UQ__Programm__9CE8238307DF55FE").IsUnique();

//            entity.Property(e => e.LanguageId).HasColumnName("language_id");
//            entity.Property(e => e.LanguageName)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("language_name");
//            entity.Property(e => e.Status)
//                .HasDefaultValue(true)
//                .HasColumnName("status");
//        });

//        modelBuilder.Entity<Request>(entity =>
//        {
//            entity.HasKey(e => e.RequestId).HasName("PK__Request__18D3B90F8AAF1A59");

//            entity.ToTable("Request");

//            entity.Property(e => e.RequestId).HasColumnName("request_id");
//            entity.Property(e => e.ClassDate).HasColumnName("class_date");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.Day)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("day");
//            entity.Property(e => e.LearningDuration).HasColumnName("learning_duration");
//            entity.Property(e => e.LearningDurationUnit)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("learning_duration_unit");
//            entity.Property(e => e.LearningMode)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("learning_mode");
//            entity.Property(e => e.ParentRequestId).HasColumnName("parent_request_id");
//            entity.Property(e => e.RequestDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("request_date");
//            entity.Property(e => e.RequestGroupId).HasColumnName("request_group_id");
//            entity.Property(e => e.RequestType)
//                .HasMaxLength(50)
//                .IsUnicode(false)
//                .HasColumnName("request_type");
//            entity.Property(e => e.ResponseDeadline)
//                .HasColumnType("datetime")
//                .HasColumnName("response_deadline");
//            entity.Property(e => e.Status)
//                .HasMaxLength(50)
//                .IsUnicode(false);
//            entity.Property(e => e.StudentId).HasColumnName("student_id");
//            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");
//            entity.Property(e => e.Time)
//                .HasMaxLength(100)
//                .IsUnicode(false);
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
//            entity.Property(e => e.TutorSequence).HasColumnName("tutor_sequence");

//            entity.HasOne(d => d.Course).WithMany(p => p.Requests)
//                .HasForeignKey(d => d.CourseId)
//                .HasConstraintName("FK__Request__course___078C1F06");

//            entity.HasOne(d => d.RequestGroup).WithMany(p => p.Requests)
//                .HasForeignKey(d => d.RequestGroupId)
//                .HasConstraintName("FK__Request__request__04AFB25B");

//            entity.HasOne(d => d.Student).WithMany(p => p.Requests)
//                .HasForeignKey(d => d.StudentId)
//                .HasConstraintName("FK__Request__student__05A3D694");

//            entity.HasOne(d => d.StudyGroup).WithMany(p => p.Requests)
//                .HasForeignKey(d => d.StudyGroupId)
//                .HasConstraintName("FK__Request__study_g__0880433F");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.Requests)
//                .HasForeignKey(d => d.TutorId)
//                .HasConstraintName("FK__Request__tutor_i__0697FACD");
//        });

//        modelBuilder.Entity<RequestCoursePlan>(entity =>
//        {
//            entity.HasKey(e => e.PlanId).HasName("PK__Request___BE9F8F1D504F6EA2");

//            entity.ToTable("Request_Course_Plan");

//            entity.HasIndex(e => e.RequestGroupId, "UQ__Request___30D47C28EE664CC0").IsUnique();

//            entity.Property(e => e.PlanId).HasColumnName("plan_id");
//            entity.Property(e => e.ApprovedByTutorId).HasColumnName("approved_by_tutor_id");
//            entity.Property(e => e.ApprovedDate)
//                .HasColumnType("datetime")
//                .HasColumnName("approved_date");
//            entity.Property(e => e.ClassDurationMinutes).HasColumnName("class_duration_minutes");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.OriginalClassesPerWeek).HasColumnName("original_classes_per_week");
//            entity.Property(e => e.OriginalDurationWeeks).HasColumnName("original_duration_weeks");
//            entity.Property(e => e.PlanType)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("plan_type");
//            entity.Property(e => e.RequestGroupId).HasColumnName("request_group_id");
//            entity.Property(e => e.RequestedClassesPerWeek).HasColumnName("requested_classes_per_week");
//            entity.Property(e => e.RequestedDurationWeeks).HasColumnName("requested_duration_weeks");
//            entity.Property(e => e.StartDate).HasColumnName("start_date");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Pending")
//                .HasColumnName("status");
//            entity.Property(e => e.TargetEndDate).HasColumnName("target_end_date");
//            entity.Property(e => e.TotalClasses).HasColumnName("total_classes");
//            entity.Property(e => e.TutorRemarks)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("tutor_remarks");

//            entity.HasOne(d => d.ApprovedByTutor).WithMany(p => p.RequestCoursePlans)
//                .HasForeignKey(d => d.ApprovedByTutorId)
//                .HasConstraintName("FK__Request_C__appro__6DCC4D03");

//            entity.HasOne(d => d.RequestGroup).WithOne(p => p.RequestCoursePlan)
//                .HasForeignKey<RequestCoursePlan>(d => d.RequestGroupId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Request_C__reque__6EC0713C");
//        });

//        modelBuilder.Entity<RequestGroup>(entity =>
//        {
//            entity.HasKey(e => e.RequestGroupId).HasName("PK__Request___30D47C29D1CC79D2");

//            entity.ToTable("Request_Group");

//            entity.Property(e => e.RequestGroupId).HasColumnName("request_group_id");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.CurrentRequestId).HasColumnName("current_request_id");
//            entity.Property(e => e.Status)
//                .HasMaxLength(30)
//                .IsUnicode(false)
//                .HasColumnName("status");
//            entity.Property(e => e.StudentId).HasColumnName("student_id");

//            entity.HasOne(d => d.Course).WithMany(p => p.RequestGroups)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Request_G__cours__1DB06A4F");

//            entity.HasOne(d => d.Student).WithMany(p => p.RequestGroups)
//                .HasForeignKey(d => d.StudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Request_G__stude__1CBC4616");
//        });

//        modelBuilder.Entity<Schedule>(entity =>
//        {
//            entity.HasKey(e => e.ScheduleId).HasName("PK__Schedule__C46A8A6FD9635445");

//            entity.ToTable("Schedule");

//            entity.Property(e => e.ScheduleId).HasColumnName("schedule_id");
//            entity.Property(e => e.Day)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("day");
//            entity.Property(e => e.EndDate).HasColumnName("end_date");
//            entity.Property(e => e.StartDate).HasColumnName("start_date");
//            entity.Property(e => e.Time)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("time");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
//            entity.Property(e => e.Type)
//                .HasMaxLength(50)
//                .IsUnicode(false);

//            entity.HasOne(d => d.Tutor).WithMany(p => p.Schedules)
//                .HasForeignKey(d => d.TutorId)
//                .HasConstraintName("FK__Schedule__tutor___7C4F7684");
//        });

//        modelBuilder.Entity<Student>(entity =>
//        {
//            entity.HasKey(e => e.StudentId).HasName("PK__Student__2A33069A61A82BB6");

//            entity.ToTable("Student");

//            entity.Property(e => e.StudentId).HasColumnName("student_id");
//            entity.Property(e => e.FatherCnic)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("Father_Cnic");
//            entity.Property(e => e.FeeResponsibility)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("fee_responsibility");
//            entity.Property(e => e.Location)
//                .IsUnicode(false)
//                .HasColumnName("location");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("status");
//            entity.Property(e => e.UserId).HasColumnName("user_id");

//            entity.HasOne(d => d.User).WithMany(p => p.Students)
//                .HasForeignKey(d => d.UserId)
//                .HasConstraintName("FK__Student__user_id__73BA3083");
//        });

//        modelBuilder.Entity<StudentCourse>(entity =>
//        {
//            entity.HasKey(e => new { e.StudentId, e.CourseId }).HasName("PK__Student___D2C2E9E02F085B24");

//            entity.ToTable("Student_Course");

//            entity.Property(e => e.StudentId).HasColumnName("student_id");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.Grade)
//                .HasMaxLength(10)
//                .IsUnicode(false)
//                .HasColumnName("grade");
//            entity.Property(e => e.PreferredLanguageId).HasColumnName("preferred_language_id");

//            entity.HasOne(d => d.Course).WithMany(p => p.StudentCourses)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_C__cours__0C85DE4D");

//            entity.HasOne(d => d.PreferredLanguage).WithMany(p => p.StudentCourses)
//                .HasForeignKey(d => d.PreferredLanguageId)
//                .HasConstraintName("FK__Student_C__prefe__0D7A0286");

//            entity.HasOne(d => d.Student).WithMany(p => p.StudentCourses)
//                .HasForeignKey(d => d.StudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_C__stude__0B91BA14");
//        });

//        modelBuilder.Entity<StudentCourseContent>(entity =>
//        {
//            entity.HasKey(e => e.ContentId).HasName("PK__Student___655FE51046CD6DCA");

//            entity.ToTable("Student_Course_Content");

//            entity.Property(e => e.ContentId).HasColumnName("content_id");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.Description)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("description");
//            entity.Property(e => e.FileName)
//                .HasMaxLength(255)
//                .IsUnicode(false)
//                .HasColumnName("file_name");
//            entity.Property(e => e.FilePath)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("file_path");
//            entity.Property(e => e.StudentId).HasColumnName("student_id");
//            entity.Property(e => e.Title)
//                .HasMaxLength(150)
//                .IsUnicode(false)
//                .HasColumnName("title");
//            entity.Property(e => e.UploadedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("uploaded_date");

//            entity.HasOne(d => d.Course).WithMany(p => p.StudentCourseContents)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_C__cours__236943A5");

//            entity.HasOne(d => d.Student).WithMany(p => p.StudentCourseContents)
//                .HasForeignKey(d => d.StudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_C__stude__22751F6C");
//        });

//        modelBuilder.Entity<StudentCourseFee>(entity =>
//        {
//            entity.HasKey(e => e.FeeId).HasName("PK__Student___A19C8AFB2A507020");

//            entity.ToTable("Student_Course_Fee");

//            entity.HasIndex(e => new { e.StudentId, e.TutorId, e.CourseId }, "UQ__Student___80B1FDBCE370277E").IsUnique();

//            entity.Property(e => e.FeeId).HasColumnName("fee_id");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.FeeResponsibility)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Parent")
//                .HasColumnName("fee_responsibility");
//            entity.Property(e => e.StudentId).HasColumnName("student_id");
//            entity.Property(e => e.TotalFee)
//                .HasColumnType("decimal(10, 2)")
//                .HasColumnName("total_fee");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

//            entity.HasOne(d => d.Course).WithMany(p => p.StudentCourseFees)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_C__cours__18EBB532");

//            entity.HasOne(d => d.Student).WithMany(p => p.StudentCourseFees)
//                .HasForeignKey(d => d.StudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_C__stude__17036CC0");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.StudentCourseFees)
//                .HasForeignKey(d => d.TutorId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_C__tutor__17F790F9");
//        });

//        modelBuilder.Entity<StudentFriend>(entity =>
//        {
//            entity.HasKey(e => e.FriendshipId).HasName("PK__Student___BC802BCF95974579");

//            entity.ToTable("Student_Friend");

//            entity.Property(e => e.FriendshipId).HasColumnName("friendship_id");
//            entity.Property(e => e.AcceptedDate)
//                .HasColumnType("datetime")
//                .HasColumnName("accepted_date");
//            entity.Property(e => e.FriendStudentId).HasColumnName("friend_student_id");
//            entity.Property(e => e.RequestedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("requested_date");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Pending")
//                .HasColumnName("status");
//            entity.Property(e => e.StudentId).HasColumnName("student_id");

//            entity.HasOne(d => d.FriendStudent).WithMany(p => p.StudentFriendFriendStudents)
//                .HasForeignKey(d => d.FriendStudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_F__frien__2A164134");

//            entity.HasOne(d => d.Student).WithMany(p => p.StudentFriendStudents)
//                .HasForeignKey(d => d.StudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Student_F__stude__29221CFB");
//        });

//        modelBuilder.Entity<StudentSchedule>(entity =>
//        {
//            entity.HasKey(e => e.ScheduleId).HasName("PK__Student___C46A8A6F22A72894");

//            entity.ToTable("Student_Schedule");

//            entity.Property(e => e.ScheduleId).HasColumnName("schedule_id");
//            entity.Property(e => e.Day)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("day");
//            entity.Property(e => e.EndDate).HasColumnName("end_date");
//            entity.Property(e => e.StartDate).HasColumnName("start_date");
//            entity.Property(e => e.StudentId).HasColumnName("student_id");
//            entity.Property(e => e.Time)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("time");
//            entity.Property(e => e.Type)
//                .HasMaxLength(50)
//                .IsUnicode(false);

//            entity.HasOne(d => d.Student).WithMany(p => p.StudentSchedules)
//                .HasForeignKey(d => d.StudentId)
//                .HasConstraintName("FK__Student_S__stude__00200768");
//        });

//        modelBuilder.Entity<StudyGroup>(entity =>
//        {
//            entity.HasKey(e => e.StudyGroupId).HasName("PK__Study_Gr__2471BA042829383E");

//            entity.ToTable("Study_Group");

//            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.CreatedByStudentId).HasColumnName("created_by_student_id");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.GroupName)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("group_name");
//            entity.Property(e => e.MaxStudents)
//                .HasDefaultValue(10)
//                .HasColumnName("max_students");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Open")
//                .HasColumnName("status");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

//            entity.HasOne(d => d.Course).WithMany(p => p.StudyGroups)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Study_Gro__cours__32AB8735");

//            entity.HasOne(d => d.CreatedByStudent).WithMany(p => p.StudyGroups)
//                .HasForeignKey(d => d.CreatedByStudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Study_Gro__creat__31B762FC");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.StudyGroups)
//                .HasForeignKey(d => d.TutorId)
//                .HasConstraintName("FK__Study_Gro__tutor__339FAB6E");
//        });

//        modelBuilder.Entity<StudyGroupInvitation>(entity =>
//        {
//            entity.HasKey(e => e.InvitationId).HasName("PK__Study_Gr__94B74D7C7BEB83B2");

//            entity.ToTable("Study_Group_Invitation");

//            entity.Property(e => e.InvitationId).HasColumnName("invitation_id");
//            entity.Property(e => e.InvitationDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("invitation_date");
//            entity.Property(e => e.InvitedByStudentId).HasColumnName("invited_by_student_id");
//            entity.Property(e => e.InvitedStudentId).HasColumnName("invited_student_id");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Pending")
//                .HasColumnName("status");
//            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");

//            entity.HasOne(d => d.InvitedByStudent).WithMany(p => p.StudyGroupInvitationInvitedByStudents)
//                .HasForeignKey(d => d.InvitedByStudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Study_Gro__invit__56E8E7AB");

//            entity.HasOne(d => d.InvitedStudent).WithMany(p => p.StudyGroupInvitationInvitedStudents)
//                .HasForeignKey(d => d.InvitedStudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Study_Gro__invit__55F4C372");

//            entity.HasOne(d => d.StudyGroup).WithMany(p => p.StudyGroupInvitations)
//                .HasForeignKey(d => d.StudyGroupId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Study_Gro__study__55009F39");
//        });

//        modelBuilder.Entity<StudyGroupMember>(entity =>
//        {
//            entity.HasKey(e => e.GroupMemberId).HasName("PK__Study_Gr__F3C66B8C751E50DE");

//            entity.ToTable("Study_Group_Member");

//            entity.HasIndex(e => new { e.StudyGroupId, e.StudentId }, "UQ__Study_Gr__96D28A6C7A9A0199").IsUnique();

//            entity.Property(e => e.GroupMemberId).HasColumnName("group_member_id");
//            entity.Property(e => e.JoinedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("joined_date");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Active")
//                .HasColumnName("status");
//            entity.Property(e => e.StudentId).HasColumnName("student_id");
//            entity.Property(e => e.StudyGroupId).HasColumnName("study_group_id");

//            entity.HasOne(d => d.Student).WithMany(p => p.StudyGroupMembers)
//                .HasForeignKey(d => d.StudentId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Study_Gro__stude__4F47C5E3");

//            entity.HasOne(d => d.StudyGroup).WithMany(p => p.StudyGroupMembers)
//                .HasForeignKey(d => d.StudyGroupId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Study_Gro__study__4E53A1AA");
//        });

//        modelBuilder.Entity<Tutor>(entity =>
//        {
//            entity.HasKey(e => e.TutorId).HasName("PK__Tutor__50DE5D01BF10C07F");

//            entity.ToTable("Tutor");

//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
//            entity.Property(e => e.Experience).HasColumnName("experience");
//            entity.Property(e => e.Location)
//                .IsUnicode(false)
//                .HasColumnName("location");
//            entity.Property(e => e.Qualification)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("qualification");
//            entity.Property(e => e.Radius).HasColumnName("radius");
//            entity.Property(e => e.Status)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("status");
//            entity.Property(e => e.TeachingMode)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("teaching_mode");
//            entity.Property(e => e.UserId).HasColumnName("user_id");

//            entity.HasOne(d => d.User).WithMany(p => p.Tutors)
//                .HasForeignKey(d => d.UserId)
//                .HasConstraintName("FK__Tutor__user_id__70DDC3D8");
//        });

//        modelBuilder.Entity<TutorCourse>(entity =>
//        {
//            entity.HasKey(e => new { e.TutorId, e.CourseId }).HasName("PK__Tutor_Co__A82FB27B7645D8F0");

//            entity.ToTable("Tutor_Course");

//            entity.HasIndex(e => e.GradeVerificationStatus, "IX_TutorCourse_Verification");

//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.CompletedDate)
//                .HasColumnType("datetime")
//                .HasColumnName("completed_date");
//            entity.Property(e => e.Grade)
//                .HasMaxLength(10)
//                .IsUnicode(false)
//                .HasColumnName("grade");
//            entity.Property(e => e.GradeVerificationStatus)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Pending", "DF_TutorCourse_Verification")
//                .HasColumnName("grade_verification_status");
//            entity.Property(e => e.Institute)
//                .HasMaxLength(150)
//                .IsUnicode(false)
//                .HasColumnName("institute");
//            entity.Property(e => e.IsCompleted).HasColumnName("is_completed");
//            entity.Property(e => e.LabCompleted).HasColumnName("lab_completed");
//            entity.Property(e => e.VerificationRemarks)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("verification_remarks");
//            entity.Property(e => e.VerifiedBy).HasColumnName("verified_by");
//            entity.Property(e => e.VerifiedDate)
//                .HasColumnType("datetime")
//                .HasColumnName("verified_date");

//            entity.HasOne(d => d.Course).WithMany(p => p.TutorCourses)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Tutor_Cou__cours__06CD04F7");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.TutorCourses)
//                .HasForeignKey(d => d.TutorId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Tutor_Cou__tutor__05D8E0BE");

//            entity.HasOne(d => d.VerifiedByNavigation).WithMany(p => p.TutorCourses)
//                .HasForeignKey(d => d.VerifiedBy)
//                .HasConstraintName("FK__Tutor_Cou__verif__07C12930");

//            entity.HasMany(d => d.Languages).WithMany(p => p.TutorCourses)
//                .UsingEntity<Dictionary<string, object>>(
//                    "TutorCourseProgrammingLanguage",
//                    r => r.HasOne<ProgrammingLanguage>().WithMany()
//                        .HasForeignKey("LanguageId")
//                        .OnDelete(DeleteBehavior.ClientSetNull)
//                        .HasConstraintName("FK__Tutor_Cou__langu__793DFFAF"),
//                    l => l.HasOne<TutorCourse>().WithMany()
//                        .HasForeignKey("TutorId", "CourseId")
//                        .OnDelete(DeleteBehavior.ClientSetNull)
//                        .HasConstraintName("FK__Tutor_Course_Pro__7849DB76"),
//                    j =>
//                    {
//                        j.HasKey("TutorId", "CourseId", "LanguageId").HasName("PK__Tutor_Co__1AAFFE8D1BF9D2EB");
//                        j.ToTable("Tutor_Course_Programming_Language");
//                        j.IndexerProperty<int>("TutorId").HasColumnName("tutor_id");
//                        j.IndexerProperty<int>("CourseId").HasColumnName("course_id");
//                        j.IndexerProperty<int>("LanguageId").HasColumnName("language_id");
//                    });
//        });

//        modelBuilder.Entity<TutorCourseEvidence>(entity =>
//        {
//            entity.HasKey(e => e.EvidenceId).HasName("PK__Tutor_Co__C59A788E1D996C98");

//            entity.ToTable("Tutor_Course_Evidence");

//            entity.HasIndex(e => e.VerificationStatus, "IX_CourseEvidence_Status");

//            entity.Property(e => e.EvidenceId).HasColumnName("evidence_id");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.EvidenceType)
//                .HasMaxLength(30)
//                .IsUnicode(false)
//                .HasColumnName("evidence_type");
//            entity.Property(e => e.FileName)
//                .HasMaxLength(255)
//                .IsUnicode(false)
//                .HasColumnName("file_name");
//            entity.Property(e => e.FilePath)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("file_path");
//            entity.Property(e => e.Remarks)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("remarks");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
//            entity.Property(e => e.UploadedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("uploaded_date");
//            entity.Property(e => e.VerificationStatus)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasDefaultValue("Pending")
//                .HasColumnName("verification_status");
//            entity.Property(e => e.VerifiedBy).HasColumnName("verified_by");
//            entity.Property(e => e.VerifiedDate)
//                .HasColumnType("datetime")
//                .HasColumnName("verified_date");

//            entity.HasOne(d => d.VerifiedByNavigation).WithMany(p => p.TutorCourseEvidences)
//                .HasForeignKey(d => d.VerifiedBy)
//                .HasConstraintName("FK__Tutor_Cou__verif__662B2B3B");

//            entity.HasOne(d => d.TutorCourse).WithMany(p => p.TutorCourseEvidences)
//                .HasForeignKey(d => new { d.TutorId, d.CourseId })
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Tutor_Course_Evi__65370702");
//        });

//        modelBuilder.Entity<TutorCourseRate>(entity =>
//        {
//            entity.HasKey(e => e.RateId).HasName("PK__Tutor_Co__75920B4294E8F807");

//            entity.ToTable("Tutor_Course_Rate");

//            entity.Property(e => e.RateId).HasColumnName("rate_id");
//            entity.Property(e => e.AdminSetMaxHourlyRate)
//                .HasColumnType("decimal(10, 2)")
//                .HasColumnName("admin_set_max_hourly_rate");
//            entity.Property(e => e.AdminSetMinHourlyRate)
//                .HasColumnType("decimal(10, 2)")
//                .HasColumnName("admin_set_min_hourly_rate");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.HourlyRate)
//                .HasColumnType("decimal(10, 2)")
//                .HasColumnName("hourly_rate");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

//            entity.HasOne(d => d.Course).WithMany(p => p.TutorCourseRates)
//                .HasForeignKey(d => d.CourseId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Tutor_Cou__cours__114A936A");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.TutorCourseRates)
//                .HasForeignKey(d => d.TutorId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Tutor_Cou__tutor__10566F31");
//        });

//        modelBuilder.Entity<TutorPreviousTeacher>(entity =>
//        {
//            entity.HasKey(e => e.PreviousTeacherId).HasName("PK__Tutor_Pr__E6BA1949DF014DB8");

//            entity.ToTable("Tutor_Previous_Teacher");

//            entity.HasIndex(e => e.TeacherName, "IX_PreviousTeacher_Name");

//            entity.Property(e => e.PreviousTeacherId).HasColumnName("previous_teacher_id");
//            entity.Property(e => e.CourseId).HasColumnName("course_id");
//            entity.Property(e => e.CreatedDate)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("created_date");
//            entity.Property(e => e.Description)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("description");
//            entity.Property(e => e.Institute)
//                .HasMaxLength(150)
//                .IsUnicode(false)
//                .HasColumnName("institute");
//            entity.Property(e => e.StudyYear).HasColumnName("study_year");
//            entity.Property(e => e.TeacherName)
//                .HasMaxLength(150)
//                .IsUnicode(false)
//                .HasColumnName("teacher_name");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");

//            entity.HasOne(d => d.Course).WithMany(p => p.TutorPreviousTeachers)
//                .HasForeignKey(d => d.CourseId)
//                .HasConstraintName("FK__Tutor_Pre__cours__395884C4");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.TutorPreviousTeachers)
//                .HasForeignKey(d => d.TutorId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK__Tutor_Pre__tutor__3864608B");
//        });

//        modelBuilder.Entity<TutorTranscript>(entity =>
//        {
//            entity.HasKey(e => e.TranscriptId).HasName("PK__Tutor_Tr__3D043C387C95054F");

//            entity.ToTable("Tutor_Transcript");

//            entity.Property(e => e.TranscriptId).HasColumnName("transcript_id");
//            entity.Property(e => e.FileName)
//                .HasMaxLength(255)
//                .IsUnicode(false)
//                .HasColumnName("file_name");
//            entity.Property(e => e.FilePath)
//                .HasMaxLength(500)
//                .IsUnicode(false)
//                .HasColumnName("file_path");
//            entity.Property(e => e.RejectionReason)
//                .HasMaxLength(1000)
//                .HasColumnName("rejection_reason");
//            entity.Property(e => e.ReviewedAt)
//                .HasColumnType("datetime")
//                .HasColumnName("reviewed_at");
//            entity.Property(e => e.ReviewedBy).HasColumnName("reviewed_by");
//            entity.Property(e => e.Status)
//                .HasMaxLength(30)
//                .IsUnicode(false)
//                .HasDefaultValue("Pending")
//                .HasColumnName("status");
//            entity.Property(e => e.TutorId).HasColumnName("tutor_id");
//            entity.Property(e => e.UploadedAt)
//                .HasDefaultValueSql("(getdate())")
//                .HasColumnType("datetime")
//                .HasColumnName("uploaded_at");

//            entity.HasOne(d => d.Tutor).WithMany(p => p.TutorTranscripts)
//                .HasForeignKey(d => d.TutorId)
//                .OnDelete(DeleteBehavior.ClientSetNull)
//                .HasConstraintName("FK_Tutor_Transcript_Tutor");
//        });

//        modelBuilder.Entity<User>(entity =>
//        {
//            entity.HasKey(e => e.UserId).HasName("PK__Users__B9BE370FA914C184");

//            entity.HasIndex(e => e.Email, "UQ__Users__AB6E616461D60F0F").IsUnique();

//            entity.Property(e => e.UserId).HasColumnName("user_id");
//            entity.Property(e => e.Cnic)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("cnic");
//            entity.Property(e => e.Email)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("email");
//            entity.Property(e => e.FullName)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("full_name");
//            entity.Property(e => e.Password)
//                .HasMaxLength(100)
//                .IsUnicode(false)
//                .HasColumnName("password");
//            entity.Property(e => e.Phone)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("phone");
//            entity.Property(e => e.Role)
//                .HasMaxLength(20)
//                .IsUnicode(false)
//                .HasColumnName("role");
//        });

//        OnModelCreatingPartial(modelBuilder);
//    }

//    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
//}
