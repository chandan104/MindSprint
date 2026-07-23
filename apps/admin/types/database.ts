export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      app_versions: {
        Row: {
          id: string
          minimum_supported_version: string
          release_notes: string | null
          released_at: string
          version: string
        }
        Insert: {
          id?: string
          minimum_supported_version: string
          release_notes?: string | null
          released_at?: string
          version: string
        }
        Update: {
          id?: string
          minimum_supported_version?: string
          release_notes?: string | null
          released_at?: string
          version?: string
        }
        Relationships: []
      }
      assessment_modules: {
        Row: {
          created_at: string
          enabled: boolean
          module_key: string
          name: string
        }
        Insert: {
          created_at?: string
          enabled?: boolean
          module_key: string
          name: string
        }
        Update: {
          created_at?: string
          enabled?: boolean
          module_key?: string
          name?: string
        }
        Relationships: []
      }
      audit_logs: {
        Row: {
          action: string
          actor_id: string | null
          after: Json | null
          at: string
          before: Json | null
          entity: string
          entity_id: string | null
          id: number
        }
        Insert: {
          action: string
          actor_id?: string | null
          after?: Json | null
          at?: string
          before?: Json | null
          entity: string
          entity_id?: string | null
          id?: never
        }
        Update: {
          action?: string
          actor_id?: string | null
          after?: Json | null
          at?: string
          before?: Json | null
          entity?: string
          entity_id?: string | null
          id?: never
        }
        Relationships: []
      }
      categories: {
        Row: {
          created_at: string
          enabled: boolean
          id: string
          key: string
          name: string
        }
        Insert: {
          created_at?: string
          enabled?: boolean
          id?: string
          key: string
          name: string
        }
        Update: {
          created_at?: string
          enabled?: boolean
          id?: string
          key?: string
          name?: string
        }
        Relationships: []
      }
      category_items: {
        Row: {
          category_id: string
          created_at: string
          id: string
          label: string
          media_asset_id: string | null
        }
        Insert: {
          category_id: string
          created_at?: string
          id?: string
          label: string
          media_asset_id?: string | null
        }
        Update: {
          category_id?: string
          created_at?: string
          id?: string
          label?: string
          media_asset_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "category_items_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "category_items_media_asset_id_fkey"
            columns: ["media_asset_id"]
            isOneToOne: false
            referencedRelation: "media_assets"
            referencedColumns: ["id"]
          },
        ]
      }
      classes: {
        Row: {
          created_at: string
          grade: number | null
          id: string
          name: string
          school_id: string
        }
        Insert: {
          created_at?: string
          grade?: number | null
          id?: string
          name: string
          school_id: string
        }
        Update: {
          created_at?: string
          grade?: number | null
          id?: string
          name?: string
          school_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "classes_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      feature_flags: {
        Row: {
          description: string | null
          enabled: boolean
          key: string
        }
        Insert: {
          description?: string | null
          enabled?: boolean
          key: string
        }
        Update: {
          description?: string | null
          enabled?: boolean
          key?: string
        }
        Relationships: []
      }
      level_versions: {
        Row: {
          config: Json
          created_at: string
          id: string
          level_id: string
          version: number
        }
        Insert: {
          config: Json
          created_at?: string
          id?: string
          level_id: string
          version: number
        }
        Update: {
          config?: Json
          created_at?: string
          id?: string
          level_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "level_versions_level_id_fkey"
            columns: ["level_id"]
            isOneToOne: false
            referencedRelation: "levels"
            referencedColumns: ["id"]
          },
        ]
      }
      levels: {
        Row: {
          created_at: string
          difficulty: Database["public"]["Enums"]["difficulty_tier"]
          difficulty_rank: number
          enabled: boolean
          id: string
          module_key: string
          name: string
        }
        Insert: {
          created_at?: string
          difficulty?: Database["public"]["Enums"]["difficulty_tier"]
          difficulty_rank?: number
          enabled?: boolean
          id?: string
          module_key: string
          name: string
        }
        Update: {
          created_at?: string
          difficulty?: Database["public"]["Enums"]["difficulty_tier"]
          difficulty_rank?: number
          enabled?: boolean
          id?: string
          module_key?: string
          name?: string
        }
        Relationships: [
          {
            foreignKeyName: "levels_module_key_fkey"
            columns: ["module_key"]
            isOneToOne: false
            referencedRelation: "assessment_modules"
            referencedColumns: ["module_key"]
          },
        ]
      }
      media_assets: {
        Row: {
          created_at: string
          id: string
          metadata: Json
          storage_path: string
          type: Database["public"]["Enums"]["media_type"]
          uploaded_by: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          metadata?: Json
          storage_path: string
          type: Database["public"]["Enums"]["media_type"]
          uploaded_by?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          metadata?: Json
          storage_path?: string
          type?: Database["public"]["Enums"]["media_type"]
          uploaded_by?: string | null
        }
        Relationships: []
      }
      profiles: {
        Row: {
          created_at: string
          full_name: string
          id: string
        }
        Insert: {
          created_at?: string
          full_name: string
          id: string
        }
        Update: {
          created_at?: string
          full_name?: string
          id?: string
        }
        Relationships: []
      }
      schools: {
        Row: {
          created_at: string
          id: string
          name: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
        }
        Relationships: []
      }
      session_events: {
        Row: {
          event_type: string
          payload: Json
          recorded_at: string
          seq: number
          session_id: string
          t_ms: number
        }
        Insert: {
          event_type: string
          payload?: Json
          recorded_at?: string
          seq: number
          session_id: string
          t_ms: number
        }
        Update: {
          event_type?: string
          payload?: Json
          recorded_at?: string
          seq?: number
          session_id?: string
          t_ms?: number
        }
        Relationships: [
          {
            foreignKeyName: "session_events_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      session_events_2026_07: {
        Row: {
          event_type: string
          payload: Json
          recorded_at: string
          seq: number
          session_id: string
          t_ms: number
        }
        Insert: {
          event_type: string
          payload?: Json
          recorded_at?: string
          seq: number
          session_id: string
          t_ms: number
        }
        Update: {
          event_type?: string
          payload?: Json
          recorded_at?: string
          seq?: number
          session_id?: string
          t_ms?: number
        }
        Relationships: []
      }
      session_events_2026_08: {
        Row: {
          event_type: string
          payload: Json
          recorded_at: string
          seq: number
          session_id: string
          t_ms: number
        }
        Insert: {
          event_type: string
          payload?: Json
          recorded_at?: string
          seq: number
          session_id: string
          t_ms: number
        }
        Update: {
          event_type?: string
          payload?: Json
          recorded_at?: string
          seq?: number
          session_id?: string
          t_ms?: number
        }
        Relationships: []
      }
      session_events_2026_09: {
        Row: {
          event_type: string
          payload: Json
          recorded_at: string
          seq: number
          session_id: string
          t_ms: number
        }
        Insert: {
          event_type: string
          payload?: Json
          recorded_at?: string
          seq: number
          session_id: string
          t_ms: number
        }
        Update: {
          event_type?: string
          payload?: Json
          recorded_at?: string
          seq?: number
          session_id?: string
          t_ms?: number
        }
        Relationships: []
      }
      session_events_2026_10: {
        Row: {
          event_type: string
          payload: Json
          recorded_at: string
          seq: number
          session_id: string
          t_ms: number
        }
        Insert: {
          event_type: string
          payload?: Json
          recorded_at?: string
          seq: number
          session_id: string
          t_ms: number
        }
        Update: {
          event_type?: string
          payload?: Json
          recorded_at?: string
          seq?: number
          session_id?: string
          t_ms?: number
        }
        Relationships: []
      }
      session_metrics: {
        Row: {
          accuracy: number | null
          computed_at: string
          error_count: number | null
          extra: Json
          metrics_version: number
          session_id: string
          total_time_ms: number | null
        }
        Insert: {
          accuracy?: number | null
          computed_at?: string
          error_count?: number | null
          extra?: Json
          metrics_version: number
          session_id: string
          total_time_ms?: number | null
        }
        Update: {
          accuracy?: number | null
          computed_at?: string
          error_count?: number | null
          extra?: Json
          metrics_version?: number
          session_id?: string
          total_time_ms?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "session_metrics_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      sessions: {
        Row: {
          class_id: string
          completed_at: string | null
          created_at: string
          device_meta: Json
          event_schema_version: number
          id: string
          level_version_id: string
          module_key: string
          provisional_metrics: Json | null
          school_id: string
          started_at: string
          status: Database["public"]["Enums"]["session_status"]
          student_id: string
          teacher_id: string
          was_interrupted: boolean
        }
        Insert: {
          class_id: string
          completed_at?: string | null
          created_at?: string
          device_meta?: Json
          event_schema_version?: number
          id: string
          level_version_id: string
          module_key: string
          provisional_metrics?: Json | null
          school_id: string
          started_at: string
          status?: Database["public"]["Enums"]["session_status"]
          student_id: string
          teacher_id: string
          was_interrupted?: boolean
        }
        Update: {
          class_id?: string
          completed_at?: string | null
          created_at?: string
          device_meta?: Json
          event_schema_version?: number
          id?: string
          level_version_id?: string
          module_key?: string
          provisional_metrics?: Json | null
          school_id?: string
          started_at?: string
          status?: Database["public"]["Enums"]["session_status"]
          student_id?: string
          teacher_id?: string
          was_interrupted?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "sessions_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sessions_level_version_id_fkey"
            columns: ["level_version_id"]
            isOneToOne: false
            referencedRelation: "level_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sessions_module_key_fkey"
            columns: ["module_key"]
            isOneToOne: false
            referencedRelation: "assessment_modules"
            referencedColumns: ["module_key"]
          },
          {
            foreignKeyName: "sessions_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "sessions_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      students: {
        Row: {
          birth_year: number | null
          class_id: string
          created_at: string
          full_name: string
          id: string
          is_active: boolean
          roll_number: string | null
          school_id: string
        }
        Insert: {
          birth_year?: number | null
          class_id: string
          created_at?: string
          full_name: string
          id?: string
          is_active?: boolean
          roll_number?: string | null
          school_id: string
        }
        Update: {
          birth_year?: number | null
          class_id?: string
          created_at?: string
          full_name?: string
          id?: string
          is_active?: boolean
          roll_number?: string | null
          school_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "students_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "students_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_classes: {
        Row: {
          class_id: string
          created_at: string
          teacher_id: string
        }
        Insert: {
          class_id: string
          created_at?: string
          teacher_id: string
        }
        Update: {
          class_id?: string
          created_at?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_classes_class_id_fkey"
            columns: ["class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_invites: {
        Row: {
          claimed_at: string | null
          claimed_by: string | null
          created_at: string
          email: string
          id: string
          invited_by: string
          school_id: string
          status: string
          token: string
        }
        Insert: {
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string
          email: string
          id?: string
          invited_by: string
          school_id: string
          status?: string
          token?: string
        }
        Update: {
          claimed_at?: string | null
          claimed_by?: string | null
          created_at?: string
          email?: string
          id?: string
          invited_by?: string
          school_id?: string
          status?: string
          token?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_invites_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_notes: {
        Row: {
          body: string
          created_at: string
          id: string
          session_id: string | null
          student_id: string
          teacher_id: string
        }
        Insert: {
          body: string
          created_at?: string
          id?: string
          session_id?: string | null
          student_id: string
          teacher_id: string
        }
        Update: {
          body?: string
          created_at?: string
          id?: string
          session_id?: string | null
          student_id?: string
          teacher_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_notes_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teacher_notes_student_id_fkey"
            columns: ["student_id"]
            isOneToOne: false
            referencedRelation: "students"
            referencedColumns: ["id"]
          },
        ]
      }
      user_roles: {
        Row: {
          created_at: string
          role: Database["public"]["Enums"]["user_role"]
          school_id: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          role: Database["public"]["Enums"]["user_role"]
          school_id?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          role?: Database["public"]["Enums"]["user_role"]
          school_id?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_roles_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      auth_role: { Args: never; Returns: string }
      auth_school_id: { Args: never; Returns: string }
      claim_teacher_invite: { Args: { p_token: string }; Returns: undefined }
      compute_session_metrics: {
        Args: { p_session_id: string }
        Returns: undefined
      }
      custom_access_token_hook: { Args: { event: Json }; Returns: Json }
      delete_student: {
        Args: { p_reason: string; p_student_id: string }
        Returns: undefined
      }
      ensure_session_event_partitions: {
        Args: { months_ahead?: number }
        Returns: undefined
      }
      is_school_admin_of: { Args: { target_school: string }; Returns: boolean }
      is_school_member: { Args: { target_school: string }; Returns: boolean }
      is_super_admin: { Args: never; Returns: boolean }
      process_pending_sessions: { Args: { p_limit?: number }; Returns: number }
      upload_session: {
        Args: { p_events: Json; p_session: Json }
        Returns: undefined
      }
    }
    Enums: {
      difficulty_tier: "easy" | "medium" | "hard"
      media_type: "image" | "icon" | "audio" | "animation"
      session_status: "uploaded" | "validated" | "invalid"
      user_role: "super_admin" | "school_admin" | "teacher"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      difficulty_tier: ["easy", "medium", "hard"],
      media_type: ["image", "icon", "audio", "animation"],
      session_status: ["uploaded", "validated", "invalid"],
      user_role: ["super_admin", "school_admin", "teacher"],
    },
  },
} as const
