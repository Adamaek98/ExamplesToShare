import matplotlib.pyplot as plt 
import numpy as np 
import pandas as pd 
import sklearn.neighbors

def prepare_country_stats(oecd_bli, gdp_per_capita):
    oecd_bli.rename(columns={'Subjective well-being': 'Life satisfaction'}, inplace=True)
    gdp_per_capita.rename(columns={'Unit of measure': 'Country', 'US dollars per person, PPP converted, 2015': 'GDP per capita'}, inplace=True)
    merged_data = pd.merge(oecd_bli, gdp_per_capita, on='Country')
    merged_data.dropna(subset=['GDP per capita', 'Life satisfaction'], inplace=True)
    return merged_data

oecd_bli = pd.read_excel(r"#twoja sciezka pliku#", engine='openpyxl', header=0) #### usunalem swoje zrodlo
gdp_per_capita = pd.read_excel(r"#twoja sciezka pliku#", engine='openpyxl', header=0, na_values="n/a") #### usunalem swoje zrodlo

country_stats = prepare_country_stats(oecd_bli, gdp_per_capita)
X = np.c_[country_stats["GDP per capita"]]
y = np.c_[country_stats["Life satisfaction"]]

country_stats.plot(kind='scatter', x="GDP per capita", y="Life satisfaction", color='red')
#plt.show()

model = sklearn.neighbors.KNeighborsRegressor(n_neighbors=3)
model.fit(X, y)

# Prognoza dla nowej wartości GDP per capita
X_new = [[36000]]  # Wprowadź przykładową wartość GDP per capita
prediction = model.predict(X_new)

print("Prognozowane zadowolenie z życia:", prediction)
