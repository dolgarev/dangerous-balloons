package Settings is

   -- Maze dimensions
   Max_Rows : constant := 23;
   Max_Cols : constant := 23;

   -- Game Rules
   Max_Levels       : constant := 10;
   Initial_Lives    : constant := 3;
   Initial_Level    : constant := 1;
   Initial_Balloons : constant := 4;
   Max_Bombs        : constant := 5;
   Max_Balloons     : constant := 20;
   Bomb_Timer_Sec   : constant := 5;
   Mode_Switch_Sec  : constant := 8;
   Brick_Probability : constant := 40; -- Probability to spawn a brick adjacent to a wall (1-100)

   -- Scoring
   Score_Brick     : constant := 10;
   Score_Balloon_F : constant := 50;
   Score_Balloon_H : constant := 100;

   -- Animations (in 50ms ticks)
   Explosion_Duration_Ticks : constant := 10;
   Balloon_Death_Ticks      : constant := 60;
   Player_Death_Ticks       : constant := 80;
   Balloon_Move_Tick_Rate   : constant := 10;

   -- Visuals
   Char_Wall        : constant Character := '#';
   Char_Brick       : constant Character := ' ';
   Char_Player      : constant Character := '@';
   Char_Balloon     : constant Character := 'Q';
   Char_Explosion   : constant Character := '*';
   Char_Dead_Player : constant Character := 'X';

   -- Color Pair IDs
   Color_Wall_ID      : constant := 1;
   Color_Brick_ID     : constant := 2;
   Color_Empty_ID     : constant := 3;
   Color_Player_ID    : constant := 4;
   Color_Bomb_ID      : constant := 5;
   Color_Dead_ID      : constant := 6;
   Color_Balloon_F_ID : constant := 7;
   Color_Balloon_H_ID : constant := 8;
   Color_Balloon_D_ID : constant := 9;
   Color_Status_ID    : constant := 10;

end Settings;
