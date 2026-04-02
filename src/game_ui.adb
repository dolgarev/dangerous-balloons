with Terminal_Interface.Curses; use Terminal_Interface.Curses;
with Terminal_Interface.Curses_Constants;
with Settings;                  use Settings;
with Maze;                      use Maze;
with Game_State;                use Game_State;
with Ada.Strings.Fixed;

package body Game_UI is

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

   procedure Initialize_Colors is
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
   end Initialize_Colors;

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

   procedure Draw_Frame is
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
      Refresh (Standard_Window);
   end Draw_Frame;

end Game_UI;
