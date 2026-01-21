library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top_module is
    Port (
        clk         : in  STD_LOGIC;
        switches    : in  STD_LOGIC_VECTOR(15 downto 0);
        btn_temp_up : in  STD_LOGIC;
        btn_temp_down : in  STD_LOGIC;
        seg         : out STD_LOGIC_VECTOR(6 downto 0);
        an          : out STD_LOGIC_VECTOR(7 downto 0)
    );
end top_module;

architecture Behavioral of top_module is

    component termometru is
        Port (
            clk                   : in  STD_LOGIC;
            reset                 : in  STD_LOGIC;
            switches              : in  STD_LOGIC_VECTOR(15 downto 0);
            seg                   : out STD_LOGIC_VECTOR(6 downto 0);
            btn_temp_up           : in  STD_LOGIC;
            btn_temp_down         : in  STD_LOGIC;
            an                    : out STD_LOGIC_VECTOR(7 downto 0);
            tempMin_out           : out integer range 0 to 31;
            tempMax_reg_out       : out STD_LOGIC_VECTOR(149 downto 0);
            oraMax_reg_out        : out STD_LOGIC_VECTOR(143 downto 0);
            oraCurenta_out        : out STD_LOGIC_VECTOR(5 downto 0);
            set_temp_min_done_out : out STD_LOGIC
        );
    end component;

    component simulare_temperatura is
        Port (
            clk              : in  STD_LOGIC;
            reset            : in  STD_LOGIC;
            oraCurenta_in    : in  STD_LOGIC_VECTOR(5 downto 0);
            tempMax_reg_in   : in  STD_LOGIC_VECTOR(149 downto 0);
            oraMax_reg_in    : in  STD_LOGIC_VECTOR(143 downto 0);
            sw               : in  STD_LOGIC_VECTOR(15 downto 0);
            seg              : out STD_LOGIC_VECTOR(6 downto 0);
            tempMin_in       : in  integer range 0 to 31;
            an               : out STD_LOGIC_VECTOR(7 downto 0)
        );
    end component;

    -- Interconectãri interne
    signal tempMin_internal       : integer range 0 to 31;
    signal tempMax_internal       : STD_LOGIC_VECTOR(149 downto 0);
    signal oraMax_internal        : STD_LOGIC_VECTOR(143 downto 0);
    signal set_temp_done_internal : STD_LOGIC;
    signal oraCurenta             : STD_LOGIC_VECTOR(5 downto 0) := (others => '0');

    signal seg_termometru : STD_LOGIC_VECTOR(6 downto 0);
    signal an_termometru  : STD_LOGIC_VECTOR(7 downto 0);
    signal seg_simulare   : STD_LOGIC_VECTOR(6 downto 0);
    signal an_simulare    : STD_LOGIC_VECTOR(7 downto 0);

    signal show_simulation : STD_LOGIC;
    signal reset : STD_LOGIC;

begin

    -- Reset activ când switches(15) = '1'
    reset <= switches(15);

    -- Selecteazã modul de afi?are: 1 = simulare, 0 = termometru
    show_simulation <= (switches(12) and not switches(13));

    -- Instan?iere termometru
    termometru_inst: termometru
        port map (
            clk                    => clk,
            reset                  => reset,
            switches               => switches,
            btn_temp_up            => btn_temp_up,
            btn_temp_down          => btn_temp_down,
            seg                    => seg_termometru,
            an                     => an_termometru,
            tempMin_out            => tempMin_internal,
            tempMax_reg_out        => tempMax_internal,
            oraMax_reg_out         => oraMax_internal,
            oraCurenta_out         => oraCurenta,
            set_temp_min_done_out  => set_temp_done_internal
        );

    -- Instan?iere simulare temperaturã
    simulare_inst: simulare_temperatura
        port map (
            clk              => clk,
            reset            => reset,
            oraCurenta_in    => oraCurenta,
            tempMax_reg_in   => tempMax_internal,
            oraMax_reg_in    => oraMax_internal,
            sw               => switches,
            seg              => seg_simulare,
            tempMin_in       => tempMin_internal,
            an               => an_simulare
        );

    -- Multiplexor afi?aj
    process(show_simulation, seg_termometru, an_termometru, seg_simulare, an_simulare)
    begin
        if show_simulation = '1' then
            seg <= seg_simulare;
            an  <= an_simulare;
        else
            seg <= seg_termometru;
            an  <= an_termometru;
        end if;
    end process;

end Behavioral;
