file <- "/home/quan/gama_workspace/ProjectUSTH-LUP/GAMA/models/resVar.csv"
print(file)
dataexf <- read.table(file, header=T, sep=",", dec=".")
summary(dataexf)
aovexf <- aov(Error ~ Land.price * Prob.change * Risk.control, data = dataexf)
summary(aovexf)
round(summary(aovexf)[[1]][2]/sum(summary(aovexf)[[1]][2])*100,2)