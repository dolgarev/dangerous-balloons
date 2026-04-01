with Terminal_Interface.Curses; use Terminal_Interface.Curses;
with Terminal_Interface.Curses_Constants;
with Maze;                      use Maze;
with Settings;                  use Settings;
with Ada.Exceptions;            use Ada.Exceptions;
with Ada.Text_IO;
with Ada.Calendar;              use Ada.Calendar;
with Ada.Numerics.Discrete_Random;
with Ada.Strings.Fixed;

procedure Main is
   Grid         : Maze.Grid_Type;
   Level_Backup : Maze.Grid_Type;

   Player_Row        : Integer := 2;
   Player_Col        : Integer := 2;
   Player_Dead       : Boolean := False;
   Player_Death_Tick : Integer := 0;

   Score         : Integer := 0;
   Current_Level : Integer := Settings.Initial_Level;
   Lives         : Integer := Settings.Initial_Lives;

   type Bomb_Rec is record
      Active         : Boolean := False;
      Row            : Integer := 0;
      Col            : Integer := 0;
      Timer          : Integer := 0;
      Explosion_Tick : Integer := 0;
   end record;
   Bombs : array (1 .. Settings.Max_Bombs) of Bomb_Rec;

   type Balloon_Mode is (Friendly, Hostile);
   type Balloon_Rec is record
      Active     : Boolean := False;
      Row        : Integer := 0;
      Col        : Integer := 0;
      Dir_R      : Integer := 0;
      Dir_C      : Integer := 0;
      Death_Tick : Integer := 0;
   end record;

   type Balloon_Array is array (1 .. Settings.Max_Balloons) of Balloon_Rec;
   Balloons       : Balloon_Array;
   Balloon_Backup : Balloon_Array;

   Global_Balloon_Mode : Balloon_Mode := Friendly;
   Mode_Timer          : Integer      := 0;
   Balloon_Tick        : Integer      := 0;

   Next_Tick : Time;

   subtype Rand_Range is Integer range 1 .. 100;
   package Rand_Int is new Ada.Numerics.Discrete_Random (Rand_Range);
   Gen : Rand_Int.Generator;

   Quit_Requested : Boolean := False;

   function Pad (V : Integer; N : Positive) return String is
      use Ada.Strings.Fixed;
      use Ada.Strings;
      S : constant String := Trim (V'Image, Both);
   begin
      if S'Length >= N then
         return S;
      else
         return [1 .. N - S'Length => '0'] & S;
      end if;
   end Pad;

   procedure Center_Text (Row : Line_Position; Text : String) is
      L_S : Line_Count;
      C_S : Column_Count;
   begin
      Get_Size (Standard_Window, L_S, C_S);
      declare
         Col : constant Column_Position :=
           Column_Position ((Integer (C_S) - Text'Length) / 2);
      begin
         if Col >= 0 and then Row >= 0 and then Row < Line_Position (L_S) then
            Move_Cursor (Standard_Window, Row, Col);
            Add (Standard_Window, Text);
         end if;
      end;
   end Center_Text;

   procedure Draw_Splash is
      L_S   : Line_Count;
      C_S   : Column_Count;
      Row   : Line_Position;
      -- ASCII art width (max line width)
      Art_W : constant Integer := 56;
      Col_A : Column_Position;

      procedure Safe_Print (R_Off : Integer; Text : String) is
         Target_Row : constant Line_Position := Row + Line_Position (R_Off);
      begin
         if Target_Row >= 0 and then Target_Row < Line_Position (L_S)
           and then Col_A >= 0
         then
            Move_Cursor (Standard_Window, Target_Row, Col_A);
            Add (Standard_Window, Text);
         end if;
      end Safe_Print;
   begin
      Get_Size (Standard_Window, L_S, C_S);
      Row   := Line_Position (Integer'Max (0, Integer (L_S) / 2 - 8));
      Col_A :=
        Column_Position
          (if Integer (C_S) > Art_W then (Integer (C_S) - Art_W) / 2 else 0);

      Erase (Standard_Window);

      Set_Character_Attributes (Standard_Window, Color => Color_Balloon_H_ID);
      Safe_Print (0, "  ____");
      Safe_Print (1, " |  _ \  __ _ _ __   __ _  ___ _ __ ___  _   _ ___");
      Safe_Print (2, " | | | |/ _` | '_ \ / _` |/ _ \ '__/ _ \| | | / __|");
      Safe_Print (3, " | |_| | (_| | | | | (_| |  __/ | | (_) | |_| \__ \");
      Safe_Print (4, " |____/ \__,_|_| |_|\__, |\___|_|  \___/ \__,_|___/");
      Safe_Print (5, "                    |___/");
      Safe_Print (6, "        ____        _ _");
      Safe_Print (7, "       |  _ \      | | |");
      Safe_Print (8, "       | |_) | __ _| | | ___   ___  _ __  ___");
      Safe_Print (9, "       |  _ < / _` | | |/ _ \ / _ \| '_ \/ __|");
      Safe_Print (10, "       | |_) | (_| | | | (_) | (_) | | | \__ \");
      Safe_Print (11, "       |____/ \__,_|_|_|\___/ \___/|_| |_|___/");

      Set_Character_Attributes (Standard_Window, Color => Color_Player_ID);
      Center_Text (Row + 13, "CONTROLS:");
      Center_Text (Row + 14, "  Arrows / WASD - Move your hero (@)");
      Center_Text (Row + 15, "  Space         - Place a bomb (*)");

      Set_Character_Attributes (Standard_Window, Color => Color_Balloon_F_ID);
      Center_Text (Row + 17, "GOAL: Destroy all balloons to advance!");

      Set_Character_Attributes (Standard_Window, Color => Color_Status_ID);
      Center_Text (Row + 19, "Q - Quit   R - Restart Level");

      Set_Character_Attributes (Standard_Window, Color => Color_Wall_ID);
      Center_Text (Row + 21, ">>>  Press any key to start  <<<");

      Refresh (Standard_Window);
   end Draw_Splash;

   procedure Show_Level_Selection is
      L_S               : Line_Count;
      C_S               : Column_Count;
      Row               : Line_Position;
      Key               : Key_Code;
      Current_Selection : Integer := 1;
   begin
      if Quit_Requested then
         return;
      end if;

      Get_Size (Standard_Window, L_S, C_S);
      Row := Line_Position (Integer'Max (0, Integer (L_S) / 2 - 4));

      Set_Timeout_Mode (Standard_Window, Blocking, 0);

      loop
         Erase (Standard_Window);

         Set_Character_Attributes
           (Standard_Window, Color => Color_Balloon_H_ID);
         Center_Text (Row, "  S E L E C T   L E V E L  ");

         Set_Character_Attributes (Standard_Window, Color => Color_Player_ID);
         Center_Text
           (Row + 2,
            "Choose starting level (1-" & Pad (Settings.Max_Levels, 2) & ")");

         Set_Character_Attributes (Standard_Window, Color => Color_Dead_ID);
         Center_Text
           (Row + 4, ">>>  Level " & Pad (Current_Selection, 2) & "  <<<");

         Set_Character_Attributes (Standard_Window, Color => Color_Status_ID);
         Center_Text
           (Row + 6,
            "Arrows/WASD - Select   SPACE/ENTER - Confirm   Q - Quit");

         Refresh (Standard_Window);

         Key := Get_Keystroke (Standard_Window);
         if Key /= Terminal_Interface.Curses_Constants.ERR then
            case Key is
               when Key_Cursor_Up | Key_Cursor_Right | Character'Pos ('w') |
                 Character'Pos ('W') | Character'Pos ('d') |
                 Character'Pos ('D') =>
                  if Current_Selection < Settings.Max_Levels then
                     Current_Selection := Current_Selection + 1;
                  else
                     Current_Selection := 1;
                  end if;
               when Key_Cursor_Down | Key_Cursor_Left | Character'Pos ('s') |
                 Character'Pos ('S') | Character'Pos ('a') |
                 Character'Pos ('A') =>
                  if Current_Selection > 1 then
                     Current_Selection := Current_Selection - 1;
                  else
                     Current_Selection := Settings.Max_Levels;
                  end if;
               when Character'Pos (' ') | Character'Pos (ASCII.LF) |
                 Character'Pos (ASCII.CR) =>
                  Current_Level := Current_Selection;
                  exit;
               when Character'Pos ('q') | Character'Pos ('Q') =>
                  Quit_Requested := True;
                  exit;
               when others =>
                  null;
            end case;
         end if;
      end loop;
   end Show_Level_Selection;

   procedure Spawn_Balloons is
      Placed    : Integer          := 0;
      R, C_Idx  : Integer;
      Max_Spawn : constant Integer :=
        (Settings.Initial_Balloons - 1) + Current_Level;
   begin
      for I in Balloons'Range loop
         Balloons (I).Active     := False;
         Balloons (I).Death_Tick := 0;
      end loop;

      while (Placed < Max_Spawn) and then (Placed < Balloons'Last) loop
         R     := (abs (Rand_Int.Random (Gen)) mod Maze.Max_Rows) + 1;
         C_Idx := (abs (Rand_Int.Random (Gen)) mod Maze.Max_Cols) + 1;
         if Grid (R, C_Idx) = Maze.Empty and then ((R > 4) or (C_Idx > 4)) then
            Placed                   := Placed + 1;
            Balloons (Placed).Active := True;
            Balloons (Placed).Row    := R;
            Balloons (Placed).Col    := C_Idx;
            Balloons (Placed).Dir_R  := 0;
            Balloons (Placed).Dir_C  := 0;
         end if;
      end loop;
   end Spawn_Balloons;

   procedure Reset_Level (New_Layout : Boolean := True) is
   begin
      Player_Dead       := False;
      Player_Death_Tick := 0;

      if New_Layout then
         Maze.Generate (Grid);
         Spawn_Balloons;
         Level_Backup   := Grid;
         Balloon_Backup := Balloons;
      else
         Grid     := Level_Backup;
         Balloons := Balloon_Backup;
      end if;

      Player_Row := 2;
      Player_Col := 2;
      for I in Bombs'Range loop
         Bombs (I).Active         := False;
         Bombs (I).Explosion_Tick := 0;
      end loop;
      Global_Balloon_Mode := Friendly;
      Mode_Timer          := 0;
      Next_Tick           := Clock + 0.1; -- Reset the timer properly
   end Reset_Level;

   procedure Lose_Life is
   begin
      if not Player_Dead then
         Player_Dead       := True;
         Player_Death_Tick := Player_Death_Ticks;
         if (Lives > 0) then
            Lives := Lives - 1;
         end if;
      end if;
   end Lose_Life;

   procedure Check_Explosion_Damage (B_Idx : Integer) is
      BR : constant Integer := Bombs (B_Idx).Row;
      BC : constant Integer := Bombs (B_Idx).Col;
   begin
      for DR in Integer range -1 .. 1 loop
         for DC in Integer range -1 .. 1 loop
            if abs (DR) + abs (DC) <= 1 then
               declare
                  TR : constant Integer := BR + DR;
                  TC : constant Integer := BC + DC;
               begin
                  if (TR in 1 .. Maze.Max_Rows)
                    and then (TC in 1 .. Maze.Max_Cols)
                  then
                     if Grid (TR, TC) /= Wall then
                        if (Player_Row = TR) and then (Player_Col = TC)
                          and then (not Player_Dead)
                        then
                           Lose_Life;
                        end if;

                        for J in Balloons'Range loop
                           if Balloons (J).Active
                             and then (Balloons (J).Death_Tick = 0)
                             and then (Balloons (J).Row = TR)
                             and then (Balloons (J).Col = TC)
                           then
                              Balloons (J).Death_Tick :=
                                Settings.Balloon_Death_Ticks;
                              if Global_Balloon_Mode = Friendly then
                                 Score := Score + Score_Balloon_F;
                              else
                                 Score := Score + Score_Balloon_H;
                              end if;
                           end if;
                        end loop;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end loop;
   end Check_Explosion_Damage;

   procedure Explode_Bomb (B_Idx : Integer) is
      BR : constant Integer := Bombs (B_Idx).Row;
      BC : constant Integer := Bombs (B_Idx).Col;
   begin
      Bombs (B_Idx).Explosion_Tick := Explosion_Duration_Ticks;
      for DR in Integer range -1 .. 1 loop
         for DC in Integer range -1 .. 1 loop
            if abs (DR) + abs (DC) <= 1 then
               declare
                  TR : constant Integer := BR + DR;
                  TC : constant Integer := BC + DC;
               begin
                  if (TR in 1 .. Maze.Max_Rows)
                    and then (TC in 1 .. Maze.Max_Cols)
                  then
                     if Grid (TR, TC) = Brick then
                        Score := Score + Score_Brick;
                        declare
                           Roll : constant Integer :=
                             (abs (Rand_Int.Random (Gen)) mod 100) + 1;
                        begin
                           if Roll <= Settings.Item_Appear_Prob then
                              declare
                                 Item_Roll : constant Integer :=
                                   (abs (Rand_Int.Random (Gen)) mod 100) + 1;
                              begin
                                 if Item_Roll <= Settings.Item_Life_Prob then
                                    Grid (TR, TC) := Item_Life;
                                 elsif Item_Roll <=
                                   Settings.Item_Life_Prob +
                                     Settings.Item_Score_Prob
                                 then
                                    Grid (TR, TC) := Item_Score;
                                 else
                                    Grid (TR, TC) := Door;
                                 end if;
                              end;
                           else
                              Grid (TR, TC) := Empty;
                           end if;
                        end;
                     elsif Grid (TR, TC) = Item_Life
                       or else Grid (TR, TC) = Item_Score
                     then
                        Grid (TR, TC) := Empty;
                     end if;
                  end if;
               end;
            end if;
         end loop;
      end loop;
      Check_Explosion_Damage (B_Idx);
   end Explode_Bomb;

   procedure Move_Balloons is
      function Try_Move_Towards (B : in out Balloon_Rec) return Boolean is
         DR : Integer := 0;
         DC : Integer := 0;
      begin
         if Player_Dead then
            return False;
         end if;

         if Player_Row < B.Row then
            DR := -1;
         elsif Player_Row > B.Row then
            DR := 1;
         end if;

         if DR /= 0
           and then
           (Grid (B.Row + DR, B.Col) = Maze.Empty or
            Grid (B.Row + DR, B.Col) = Maze.Item_Life or
            Grid (B.Row + DR, B.Col) = Maze.Item_Score)
         then
            B.Row := B.Row + DR;
            return True;
         end if;

         if Player_Col < B.Col then
            DC := -1;
         elsif Player_Col > B.Col then
            DC := 1;
         end if;

         if DC /= 0
           and then
           (Grid (B.Row, B.Col + DC) = Maze.Empty or
            Grid (B.Row, B.Col + DC) = Maze.Item_Life or
            Grid (B.Row, B.Col + DC) = Maze.Item_Score)
         then
            B.Col := B.Col + DC;
            return True;
         end if;

         return False;
      end Try_Move_Towards;

      procedure Random_Move (B : in out Balloon_Rec) is
         Try_Dir : Integer;
      begin
         Try_Dir := (abs (Rand_Int.Random (Gen)) mod 4);

         if B.Dir_R /= 0 or B.Dir_C /= 0 then
            if Grid (B.Row + B.Dir_R, B.Col + B.Dir_C) = Maze.Empty or
              Grid (B.Row + B.Dir_R, B.Col + B.Dir_C) = Maze.Item_Life or
              Grid (B.Row + B.Dir_R, B.Col + B.Dir_C) = Maze.Item_Score
            then
               if Rand_Int.Random (Gen) < 70 then
                  B.Row := B.Row + B.Dir_R;
                  B.Col := B.Col + B.Dir_C;
                  return;
               end if;
            end if;
         end if;

         for I in 1 .. 4 loop
            declare
               D  : constant Integer := (Try_Dir + I) mod 4;
               TR : Integer          := B.Row;
               TC : Integer          := B.Col;
            begin
               if D = 0 then
                  TR := TR - 1;
               elsif D = 1 then
                  TR := TR + 1;
               elsif D = 2 then
                  TC := TC - 1;
               else
                  TC := TC + 1;
               end if;

               if Grid (TR, TC) = Maze.Empty or
                 Grid (TR, TC) = Maze.Item_Life or
                 Grid (TR, TC) = Maze.Item_Score
               then
                  B.Dir_R := TR - B.Row;
                  B.Dir_C := TC - B.Col;
                  B.Row   := TR;
                  B.Col   := TC;
                  return;
               end if;
            end;
         end loop;
      end Random_Move;

      procedure Handle_Balloon_Collision (R, C : Integer) is
      begin
         if Grid (R, C) = Maze.Item_Score then
            if Score > Settings.Score_Bonus_Points then
               Score := Score - Settings.Score_Bonus_Points;
            else
               Score := 0;
            end if;
         end if;
         if Grid (R, C) = Maze.Item_Life or Grid (R, C) = Maze.Item_Score then
            Grid (R, C) := Maze.Empty;
         end if;
      end Handle_Balloon_Collision;

   begin
      for I in Balloons'Range loop
         if Balloons (I).Active and then (Balloons (I).Death_Tick = 0) then
            if Global_Balloon_Mode = Hostile then
               if not Try_Move_Towards (Balloons (I)) then
                  Random_Move (Balloons (I));
               end if;
            else
               Random_Move (Balloons (I));
            end if;

            Handle_Balloon_Collision (Balloons (I).Row, Balloons (I).Col);

            if (Balloons (I).Row = Player_Row)
              and then (Balloons (I).Col = Player_Col)
              and then (not Player_Dead)
            then
               Lose_Life;
            end if;
         end if;
      end loop;
   end Move_Balloons;

   procedure Check_Level_Cleared is
      Any_Active : Boolean := False;
   begin
      if Player_Dead then
         return;
      end if;

      for I in Balloons'Range loop
         if Balloons (I).Active then
            Any_Active := True;
            exit;
         end if;
      end loop;

      if not Any_Active then
         Current_Level := Current_Level + 1;
         if Current_Level > Settings.Max_Levels then
            Current_Level := 1;
         end if;
         Reset_Level (New_Layout => True);
      end if;
   end Check_Level_Cleared;

   procedure Handle_Player_Collision is
   begin
      case Grid (Player_Row, Player_Col) is
         when Maze.Item_Life =>
            if Lives < Settings.Max_Lives_Limit then
               Lives := Lives + 1;
            else
               Score := Score + Settings.Score_Extra_Life;
            end if;
            Grid (Player_Row, Player_Col) := Maze.Empty;
         when Maze.Item_Score =>
            Score := Score + Settings.Score_Bonus_Points;
            Grid (Player_Row, Player_Col) := Maze.Empty;
         when Maze.Door =>
            Current_Level := Current_Level + 1;
            if Current_Level > Settings.Max_Levels then
               Current_Level := 1;
            end if;
            Reset_Level (New_Layout => True);
         when others =>
            null;
      end case;
   end Handle_Player_Collision;

   Ch : Key_Code;
begin
   Rand_Int.Reset (Gen);

   begin
      Init_Screen;
      Set_Echo_Mode (False);
      Set_CBreak_Mode (True);
      Set_KeyPad_Mode (Standard_Window, True);

      declare
         Vis : Cursor_Visibility := Invisible;
      begin
         Set_Cursor_Visibility (Vis);
      exception
         when others =>
            null;
      end;
   exception
      when E : others =>
         Ada.Text_IO.Put_Line
           ("Failed to initialize screen: " & Exception_Message (E));
         return;
   end;

   if Has_Colors then
      begin
         Start_Color;
         Init_Pair (Color_Wall_ID, White, Blue);
         Init_Pair (Color_Brick_ID, Yellow, Blue);
         Init_Pair (Color_Empty_ID, Green, Black);
         Init_Pair (Color_Player_ID, Cyan, Black);
         Init_Pair (Color_Bomb_ID, White, Red);
         Init_Pair (Color_Dead_ID, White, Red);
         Init_Pair (Color_Balloon_F_ID, Magenta, Black);
         Init_Pair (Color_Balloon_H_ID, Red, Black);
         Init_Pair (Color_Balloon_D_ID, White, Black);
         Init_Pair (Color_Status_ID, White, Black);
         Init_Pair (Color_Item_Life_ID, Green, Blue);
         Init_Pair (Color_Item_Score_ID, Yellow, Blue);
         Init_Pair (Color_Door_ID, White, Blue);
      exception
         when others =>
            null;
      end;
   end if;

   Main_Loop :
   loop
      Quit_Requested := False;

      Draw_Splash;
      Set_Timeout_Mode (Standard_Window, Blocking, 0);
      Ch := Get_Keystroke (Standard_Window);
      if Ch = Character'Pos ('q') or else Ch = Character'Pos ('Q') then
         exit Main_Loop;
      end if;

      Show_Level_Selection;
      if Quit_Requested then
         exit Main_Loop;
      end if;

      Score := 0;
      Lives := Settings.Initial_Lives;
      Reset_Level (New_Layout => True);

      Game_Loop :
      loop
         Set_Timeout_Mode (Standard_Window, Non_Blocking, 0);

         if Clock >= Next_Tick then
            Next_Tick := Next_Tick + 1.0;

            Mode_Timer := Mode_Timer + 1;
            if Mode_Timer >= Settings.Mode_Switch_Sec then
               Mode_Timer := 0;
               if Global_Balloon_Mode = Friendly then
                  Global_Balloon_Mode := Hostile;
               else
                  Global_Balloon_Mode := Friendly;
               end if;
            end if;

            for I in Bombs'Range loop
               if Bombs (I).Active and then (Bombs (I).Explosion_Tick = 0) then
                  Bombs (I).Timer := Bombs (I).Timer - 1;
                  if Bombs (I).Timer <= 0 then
                     Explode_Bomb (I);
                  end if;
               end if;
            end loop;
         end if;

         for I in Bombs'Range loop
            if Bombs (I).Active and then (Bombs (I).Explosion_Tick > 0) then
               Bombs (I).Explosion_Tick := Bombs (I).Explosion_Tick - 1;
               if Bombs (I).Explosion_Tick <= 0 then
                  Bombs (I).Active := False;
                  if not Player_Dead then
                     Check_Level_Cleared;
                  end if;
               else
                  Check_Explosion_Damage (I);
               end if;
            end if;
         end loop;

         for I in Balloons'Range loop
            if Balloons (I).Active then
               if Balloons (I).Death_Tick > 0 then
                  Balloons (I).Death_Tick := Balloons (I).Death_Tick - 1;
                  if Balloons (I).Death_Tick <= 0 then
                     Balloons (I).Active := False;
                     if not Player_Dead then
                        Check_Level_Cleared;
                     end if;
                  end if;
               end if;
            end if;
         end loop;

         if (Player_Dead and then (Player_Death_Tick > 0)) then
            Player_Death_Tick := Player_Death_Tick - 1;
            if Lives = 0 then
               Flush_Input;
            end if;
            if (Player_Death_Tick = 0 and then Lives > 0) then
               Reset_Level (New_Layout => False);
            end if;
         end if;

         Balloon_Tick := Balloon_Tick + 1;
         if (Balloon_Tick >= Balloon_Move_Tick_Rate) then
            Balloon_Tick := 0;
            Move_Balloons;
         end if;

         declare
            L_Count : Line_Count;
            C_Count : Column_Count;
         begin
            Get_Size (Standard_Window, L_Count, C_Count);
            Erase (Standard_Window);

            declare
               L_Off : Line_Position   :=
                 Line_Position (Integer (L_Count) - (Maze.Max_Rows + 2)) / 2;
               C_Off : Column_Position :=
                 Column_Position (Integer (C_Count) - Maze.Max_Cols) / 2;
            begin
               if L_Off < 0 then
                  L_Off := 0;
               end if;
               if C_Off < 0 then
                  C_Off := 0;
               end if;

               for R in 1 .. Maze.Max_Rows loop
                  for C_Idx in 1 .. Maze.Max_Cols loop
                     if (Integer (L_Off) + (R - 1) < Integer (L_Count))
                       and then
                       (Integer (C_Off) + (C_Idx - 1) < Integer (C_Count))
                     then
                        Move_Cursor
                          (Standard_Window, L_Off + Line_Position (R - 1),
                           C_Off + Column_Position (C_Idx - 1));
                        case Grid (R, C_Idx) is
                           when Maze.Wall =>
                              Set_Character_Attributes
                                (Standard_Window, Color => Color_Wall_ID);
                              Add
                                (Standard_Window,
                                 String'[1 => Settings.Char_Wall]);
                           when Maze.Brick =>
                              Set_Character_Attributes
                                (Standard_Window, Color => Color_Brick_ID);
                              Add
                                (Standard_Window,
                                 String'[1 => Settings.Char_Brick]);
                           when Maze.Empty =>
                              Set_Character_Attributes
                                (Standard_Window, Color => Color_Empty_ID);
                              Add (Standard_Window, " ");
                           when Maze.Item_Life =>
                              Set_Character_Attributes
                                (Standard_Window, Color => Color_Item_Life_ID);
                              Add
                                (Standard_Window,
                                 String'[1 => Settings.Char_Item_Life]);
                           when Maze.Item_Score =>
                              Set_Character_Attributes
                                (Standard_Window,
                                 Color => Color_Item_Score_ID);
                              Add
                                (Standard_Window,
                                 String'[1 => Settings.Char_Item_Score]);
                           when Maze.Door =>
                              Set_Character_Attributes
                                (Standard_Window,
                                 Attr  => (Blink => True, others => False),
                                 Color => Color_Door_ID);
                              Add
                                (Standard_Window,
                                 String'[1 => Settings.Char_Door]);
                        end case;
                     end if;
                  end loop;
               end loop;

               for I in Bombs'Range loop
                  if Bombs (I).Active then
                     if Bombs (I).Explosion_Tick > 0 then
                        for DR in Integer range -1 .. 1 loop
                           for DC in Integer range -1 .. 1 loop
                              if abs (DR) + abs (DC) <= 1 then
                                 declare
                                    TR : constant Integer :=
                                      Bombs (I).Row + DR;
                                    TC : constant Integer :=
                                      Bombs (I).Col + DC;
                                 begin
                                    if (TR in 1 .. Maze.Max_Rows)
                                      and then (TC in 1 .. Maze.Max_Cols)
                                    then
                                       if Grid (TR, TC) /= Wall then
                                          if
                                            (Integer (L_Off) + (TR - 1) <
                                             Integer (L_Count))
                                            and then
                                            (Integer (C_Off) + (TC - 1) <
                                             Integer (C_Count))
                                          then
                                             Move_Cursor
                                               (Standard_Window,
                                                L_Off + Line_Position (TR - 1),
                                                C_Off +
                                                Column_Position (TC - 1));
                                             Set_Character_Attributes
                                               (Standard_Window,
                                                Attr  =>
                                                  (Reverse_Video => True,
                                                   Blink         => True,
                                                   others        => False),
                                                Color => Color_Bomb_ID);
                                             Add
                                               (Standard_Window,
                                                String'
                                                  [1 =>
                                                    Settings.Char_Explosion]);
                                          end if;
                                       end if;
                                    end if;
                                 end;
                              end if;
                           end loop;
                        end loop;
                        Set_Character_Attributes
                          (Standard_Window, Attr => (others => False),
                           Color                 => Color_Empty_ID);
                     else
                        if
                          (Integer (L_Off) + (Bombs (I).Row - 1) <
                           Integer (L_Count))
                          and then
                          (Integer (C_Off) + (Bombs (I).Col - 1) <
                           Integer (C_Count))
                        then
                           Move_Cursor
                             (Standard_Window,
                              L_Off + Line_Position (Bombs (I).Row - 1),
                              C_Off + Column_Position (Bombs (I).Col - 1));
                           Set_Character_Attributes
                             (Standard_Window, Color => Color_Bomb_ID);
                           declare
                              C_Num : constant Character :=
                                Character'Val
                                  (Character'Pos ('0') + Bombs (I).Timer);
                              S     : constant String    := "" & C_Num;
                           begin
                              Add (Standard_Window, S);
                           end;
                        end if;
                     end if;
                  end if;
               end loop;

               for I in Balloons'Range loop
                  if Balloons (I).Active then
                     if
                       (Integer (L_Off) + (Balloons (I).Row - 1) <
                        Integer (L_Count))
                       and then
                       (Integer (C_Off) + (Balloons (I).Col - 1) <
                        Integer (C_Count))
                     then
                        Move_Cursor
                          (Standard_Window,
                           L_Off + Line_Position (Balloons (I).Row - 1),
                           C_Off + Column_Position (Balloons (I).Col - 1));
                        if Balloons (I).Death_Tick > 0 then
                           Set_Character_Attributes
                             (Standard_Window,
                              Attr  => (Blink => True, others => False),
                              Color => Color_Balloon_D_ID);
                        elsif Global_Balloon_Mode = Friendly then
                           Set_Character_Attributes
                             (Standard_Window, Color => Color_Balloon_F_ID);
                        else
                           Set_Character_Attributes
                             (Standard_Window, Color => Color_Balloon_H_ID);
                        end if;
                        Add
                          (Standard_Window,
                           String'[1 => Settings.Char_Balloon]);
                     end if;
                  end if;
               end loop;

               if (Integer (L_Off) + (Player_Row - 1) < Integer (L_Count))
                 and then
                 (Integer (C_Off) + (Player_Col - 1) < Integer (C_Count))
               then
                  if Player_Dead then
                     if Player_Death_Tick > 0 then
                        Move_Cursor
                          (Standard_Window,
                           L_Off + Line_Position (Player_Row - 1),
                           C_Off + Column_Position (Player_Col - 1));
                        Set_Character_Attributes
                          (Standard_Window,
                           Attr  => (Blink => True, others => False),
                           Color => Color_Dead_ID);
                        Add
                          (Standard_Window,
                           String'[1 => Settings.Char_Dead_Player]);
                     end if;
                  else
                     Move_Cursor
                       (Standard_Window,
                        L_Off + Line_Position (Player_Row - 1),
                        C_Off + Column_Position (Player_Col - 1));
                     Set_Character_Attributes
                       (Standard_Window, Color => Color_Player_ID);
                     Add (Standard_Window, String'[1 => Settings.Char_Player]);
                  end if;
               end if;

               if Player_Dead and then Lives = 0 then
                  declare
                     M1 : constant String          := "  GAME OVER  ";
                     C1 : constant Column_Position :=
                       C_Off +
                       Column_Position ((Maze.Max_Cols - M1'Length) / 2);
                  begin
                     if Integer (L_Off) + Maze.Max_Rows < Integer (L_Count) then
                        Move_Cursor
                          (Standard_Window, L_Off + Line_Position (Maze.Max_Rows),
                           C1);
                        Set_Character_Attributes
                          (Standard_Window, Color => Color_Dead_ID,
                           Attr => (Blink => True, others => False));
                        Add (Standard_Window, M1);
                     end if;
                  end;
               end if;

               if Player_Dead and then Lives = 0 and then Player_Death_Tick = 0
               then
                  declare
                     M2 : constant String          := "PRESS SPACE TO RESTART";
                     C2 : constant Column_Position :=
                       C_Off +
                       Column_Position ((Maze.Max_Cols - M2'Length) / 2);
                  begin
                     if Integer (L_Off) + Maze.Max_Rows + 1 < Integer (L_Count) then
                        Move_Cursor
                          (Standard_Window,
                           L_Off + Line_Position (Maze.Max_Rows + 1), C2);
                        Set_Character_Attributes
                          (Standard_Window, Color => Color_Status_ID);
                        Add (Standard_Window, M2);
                     end if;
                  end;
               else
                  declare
                     Status  : constant String  :=
                       " LEVEL: " & Pad (Current_Level, 2) & "   SCORE: " &
                       Pad (Score, 5) & "   LIVES: " & Pad (Lives, 2) & " ";
                     Padding : constant Integer :=
                       (Integer (C_Count) - Status'Length) / 2;
                     Pad_Str :
                       constant String
                         (1 .. (if Padding > 0 then Padding else 0)) :=
                       [others => ' '];
                  begin
                     if Integer (L_Off) + Maze.Max_Rows + 1 < Integer (L_Count) then
                        Move_Cursor
                          (Standard_Window,
                           L_Off + Line_Position (Maze.Max_Rows + 1), 0);
                        Set_Character_Attributes
                          (Standard_Window, Color => Color_Status_ID);
                        Add (Standard_Window, Pad_Str & Status);
                     end if;
                  end;
               end if;
            end;
         end;

         Refresh (Standard_Window);

         Ch := Get_Keystroke (Standard_Window);
         if Ch = Character'Pos ('q') or else Ch = Character'Pos ('Q') then
            exit Game_Loop;
         elsif Ch = Character'Pos ('r') or else Ch = Character'Pos ('R') then
            if (Player_Dead and then (Player_Death_Tick = 0)) then
               if (Lives = 0) then
                  exit Game_Loop;
               else
                  Reset_Level (New_Layout => False);
               end if;
            elsif not Player_Dead then
               Reset_Level (New_Layout => False);
            end if;
         elsif
           (Player_Dead and then (Player_Death_Tick = 0 and then Lives = 0))
         then
            if Ch = Character'Pos (' ') then
               exit Game_Loop;
            end if;
         elsif (not Player_Dead)
           and then (Ch /= Terminal_Interface.Curses_Constants.ERR)
         then
            if Ch = Character'Pos (' ') then
               for I in Bombs'Range loop
                  if not Bombs (I).Active then
                     declare
                        Exists : Boolean := False;
                     begin
                        for J in Bombs'Range loop
                           if Bombs (J).Active
                             and then (Bombs (J).Row = Player_Row)
                             and then (Bombs (J).Col = Player_Col)
                           then
                              Exists := True;
                           end if;
                        end loop;
                        if not Exists then
                           Bombs (I).Active         := True;
                           Bombs (I).Row            := Player_Row;
                           Bombs (I).Col            := Player_Col;
                           Bombs (I).Timer          := Settings.Bomb_Timer_Sec;
                           Bombs (I).Explosion_Tick := 0;
                        end if;
                     end;
                     exit;
                  end if;
               end loop;
            elsif Ch = Key_Cursor_Up or else Ch = Character'Pos ('w')
              or else Ch = Character'Pos ('W')
            then
               if Grid (Player_Row - 1, Player_Col) /= Maze.Wall
                 and then Grid (Player_Row - 1, Player_Col) /= Maze.Brick
               then
                  Player_Row := Player_Row - 1;
                  Handle_Player_Collision;
                  for I in Balloons'Range loop
                     if Balloons (I).Active
                       and then (Balloons (I).Death_Tick = 0)
                       and then (Balloons (I).Row = Player_Row)
                       and then (Balloons (I).Col = Player_Col)
                     then
                        Lose_Life;
                     end if;
                  end loop;
               end if;
            elsif Ch = Key_Cursor_Down or else Ch = Character'Pos ('s')
              or else Ch = Character'Pos ('S')
            then
               if Grid (Player_Row + 1, Player_Col) /= Maze.Wall
                 and then Grid (Player_Row + 1, Player_Col) /= Maze.Brick
               then
                  Player_Row := Player_Row + 1;
                  Handle_Player_Collision;
                  for I in Balloons'Range loop
                     if Balloons (I).Active
                       and then (Balloons (I).Death_Tick = 0)
                       and then (Balloons (I).Row = Player_Row)
                       and then (Balloons (I).Col = Player_Col)
                     then
                        Lose_Life;
                     end if;
                  end loop;
               end if;
            elsif Ch = Key_Cursor_Left or else Ch = Character'Pos ('a')
              or else Ch = Character'Pos ('A')
            then
               if Grid (Player_Row, Player_Col - 1) /= Maze.Wall
                 and then Grid (Player_Row, Player_Col - 1) /= Maze.Brick
               then
                  Player_Col := Player_Col - 1;
                  Handle_Player_Collision;
                  for I in Balloons'Range loop
                     if Balloons (I).Active
                       and then (Balloons (I).Death_Tick = 0)
                       and then (Balloons (I).Row = Player_Row)
                       and then (Balloons (I).Col = Player_Col)
                     then
                        Lose_Life;
                     end if;
                  end loop;
               end if;
            elsif Ch = Key_Cursor_Right or else Ch = Character'Pos ('d')
              or else Ch = Character'Pos ('D')
            then
               if Grid (Player_Row, Player_Col + 1) /= Maze.Wall
                 and then Grid (Player_Row, Player_Col + 1) /= Maze.Brick
               then
                  Player_Col := Player_Col + 1;
                  Handle_Player_Collision;
                  for I in Balloons'Range loop
                     if Balloons (I).Active
                       and then (Balloons (I).Death_Tick = 0)
                       and then (Balloons (I).Row = Player_Row)
                       and then (Balloons (I).Col = Player_Col)
                     then
                        Lose_Life;
                     end if;
                  end loop;
               end if;
            end if;
         end if;

         delay 0.05;
      end loop Game_Loop;

   end loop Main_Loop;

   End_Windows;
exception
   when E : others =>
      End_Windows;
      Ada.Text_IO.Put_Line
        ("Unexpected error in main loop: " & Exception_Name (E) & " - " &
         Exception_Message (E));
      raise;
end Main;
