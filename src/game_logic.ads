package Game_Logic is

   procedure Reset_Level (New_Layout : Boolean := True);
   procedure Lose_Life;
   procedure Move_Balloons;
   procedure Check_Level_Cleared;
   procedure Handle_Player_Collision;
   procedure Check_Explosion_Damage (B_Idx : Integer);
   procedure Explode_Bomb (B_Idx : Integer);

end Game_Logic;
