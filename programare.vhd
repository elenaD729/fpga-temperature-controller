library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity termometru is
    Port (
        clk                   : in  STD_LOGIC;
        reset                 : in  STD_LOGIC;
        switches              : in  STD_LOGIC_VECTOR(15 downto 0);
        seg                   : out STD_LOGIC_VECTOR(6 downto 0);
        btn_temp_up           : in  std_logic;
        btn_temp_down         : in  std_logic;
        an                    : out STD_LOGIC_VECTOR(7 downto 0);
        
        tempMin_out           : out integer range 0 to 31;
        tempMax_reg_out       : out STD_LOGIC_VECTOR(149 downto 0);
        oraMax_reg_out        : out STD_LOGIC_VECTOR(143 downto 0);
        set_temp_min_done_out : out STD_LOGIC;
        oraCurenta_out        : out STD_LOGIC_VECTOR(5 downto 0)
    );
end termometru;

architecture Behavioral of termometru is

    component MPG is
        Port (
            btn : in STD_LOGIC;
            clk : in STD_LOGIC;
            en  : out STD_LOGIC
        );
    end component;

    signal valoareA, valoareB       : integer := 0;
    signal digit0, digit1, digit2, digit3 : STD_LOGIC_VECTOR(3 downto 0) := (others => '0');
    signal refresh_counter          : unsigned(19 downto 0) := (others => '0');
    signal active_digit             : integer range 0 to 7 := 0;

    signal tempMax_reg              : std_logic_vector(149 downto 0) := (others => '0');
    signal oraMax_reg               : std_logic_vector(143 downto 0) := (others => '0');

    signal btn_prev                 : std_logic := '0';
    signal btn_inc_pulse            : std_logic;
    signal btn_dec_pulse            : std_logic;

    signal tempMin                  : integer range 0 to 31 := 0;
    signal set_temp_min_done        : std_logic := '0';

    signal index_common_out         : integer range 0 to 23 := 0;
    signal oraCurenta               : STD_LOGIC_VECTOR(5 downto 0) := (others => '0');

begin

    -- output assignments
    tempMin_out            <= tempMin;
    tempMax_reg_out        <= tempMax_reg;
    oraMax_reg_out         <= oraMax_reg;
    set_temp_min_done_out  <= set_temp_min_done;
    oraCurenta_out         <= oraCurenta;

    -- debounce MPG modules
    btn_debounce_up: MPG port map (
        btn => btn_temp_up,
        clk => clk,
        en  => btn_inc_pulse
    );

    btn_debounce_down: MPG port map (
        btn => btn_temp_down,
        clk => clk,
        en  => btn_dec_pulse
    );

    -- value conversion from switches
    process(switches)
    begin
        valoareA <= to_integer(unsigned(switches(4 downto 0)));
        if to_integer(unsigned(switches(9 downto 5))) > 24 then
            valoareB <= 24;
        else
            valoareB <= to_integer(unsigned(switches(9 downto 5)));
        end if;
    end process;

    -- digit generation logic
    process(valoareA, valoareB, switches, tempMin, set_temp_min_done, reset)
    begin
        if reset = '1' then
            digit0 <= "0000";
            digit1 <= "0000";
            digit2 <= "0000";
            digit3 <= "0000";
        elsif set_temp_min_done = '0' then
            digit1 <= std_logic_vector(to_unsigned(tempMin / 10, 4));
            digit0 <= std_logic_vector(to_unsigned(tempMin mod 10, 4));
            digit3 <= std_logic_vector(to_unsigned(valoareB / 10, 4));
            digit2 <= std_logic_vector(to_unsigned(valoareB mod 10, 4));
        elsif switches(13) = '1' and switches(12) = '0' then
            digit1 <= std_logic_vector(to_unsigned(valoareA / 10, 4));
            digit0 <= std_logic_vector(to_unsigned(valoareA mod 10, 4));
            digit3 <= std_logic_vector(to_unsigned(valoareB / 10, 4));
            digit2 <= std_logic_vector(to_unsigned(valoareB mod 10, 4));
        else
            digit0 <= "1111"; digit1 <= "1111"; digit2 <= "1111"; digit3 <= "1111";
        end if;
    end process;

    -- tempMin setting and ora curenta
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tempMin             <= 0;
                set_temp_min_done   <= '0';
                oraCurenta          <= (others => '0');
            elsif set_temp_min_done = '0' then
                if btn_inc_pulse = '1' and tempMin < 31 then
                    tempMin <= tempMin + 1;
                end if;

                if btn_dec_pulse = '1' and tempMin > 0 then
                    tempMin <= tempMin - 1;
                end if;

                if switches(11) = '1' then
                    set_temp_min_done <= '1';
                    oraCurenta <= std_logic_vector(to_unsigned(valoareB, 6));
                end if;
            end if;
        end if;
    end process;

    -- register temperature/hour setting
    process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then
                tempMax_reg       <= (others => '0');
                oraMax_reg        <= (others => '0');
                index_common_out  <= 0;
                btn_prev          <= '0';
            else
                refresh_counter <= refresh_counter + 1;
                if refresh_counter(13 downto 0) = 0 then
                    active_digit <= (active_digit + 1) mod 8;
                end if;

                if set_temp_min_done = '1' then
                    if switches(14) = '1' and btn_prev = '0' and switches(13) = '1' and switches(12) = '0' then
                        if index_common_out < 24 then
                            tempMax_reg((index_common_out*5 + 4) downto index_common_out*5) <= std_logic_vector(to_unsigned(valoareA, 5));
                            oraMax_reg((index_common_out*6 + 5) downto index_common_out*6)   <= std_logic_vector(to_unsigned(valoareB, 6));
                            index_common_out <= index_common_out + 1;
                        end if;
                    end if;
                end if;

                btn_prev <= switches(14);
            end if;
        end if;
    end process;

    -- 7-segment display multiplexing
    process(active_digit, digit0, digit1, digit2, digit3, reset)
        variable current_digit : STD_LOGIC_VECTOR(3 downto 0);
    begin
        if reset = '1' then
            an  <= "11111110"; -- aprinde prima cifrã
            seg <= "1000000";  -- afi?eazã 0
        else
            an <= "11111111"; -- toate oprite
            case active_digit is
                when 0 => an <= "11111110"; current_digit := digit0;
                when 1 => an <= "11111101"; current_digit := digit1;
                when 2 => an <= "11111011"; current_digit := digit2;
                when 3 => an <= "11110111"; current_digit := digit3;
                when others => current_digit := "1111";
            end case;

            case current_digit is
                when "0000" => seg <= "1000000";
                when "0001" => seg <= "1111001";
                when "0010" => seg <= "0100100";
                when "0011" => seg <= "0110000";
                when "0100" => seg <= "0011001";
                when "0101" => seg <= "0010010";
                when "0110" => seg <= "0000010";
                when "0111" => seg <= "1111000";
                when "1000" => seg <= "0000000";
                when "1001" => seg <= "0010000";
                when others => seg <= "1111111"; -- blank
            end case;
        end if;
    end process;

end Behavioral;
