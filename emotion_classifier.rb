class EmotionClassifier
      
    def initialize(total_dissatisfaction,total_energy,total_stress,count)
        @average_dissatisfaction=total_dissatisfaction.to_f/count
        @average_energy=total_energy.to_f/count
        @average_stress=total_stress.to_f/count
        @count=count
    end
    
    def average_dissatisfaction
        @average_dissatisfaction
    end

    def average_energy
        @average_energy
    end

    def average_stress
        @average_stress
    end
    
    # 不満の区分
    def dissatisfaction
        if @average_dissatisfaction==0
            "低い"
        else
            "高い"
        end
    end

    # エネルギーの区分
    def energy
        if @average_energy<5
            "低い"
        elsif @average_energy<10
            "やや低い"
        elsif @average_energy<20
            "やや高い"
        else
            "高い"
        end
    end

    # ストレスの区分
    def stress
        if @average_stress<10
            "低い"
        elsif @average_stress<16
            "やや低い"
        elsif @average_stress<25
            "やや高い"
        else
            "高い"
        end
    end
    
end
