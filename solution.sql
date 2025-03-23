/* Исходнфе данные */

CREATE SCHEMA raw_data;

CREATE TABLE raw_data.sales (
	id INTEGER PRIMARY KEY,
	auto VARCHAR,
	gasoline_consumption NUMERIC(3, 1),
	price NUMERIC(9, 2),
	date DATE,
	person_name VARCHAR,
	phone VARCHAR,
	discount INTEGER,
	brand_origin VARCHAR
);

COPY raw_data.sales FROM 'D:\YaPract\CARS.CSV' WITH CSV DELIMITER ',' NULL 'null' HEADER;




/* Создание структуры */

CREATE SCHEMA car_shop;

CREATE TABLE car_shop.brand_origin (
	id serial PRIMARY KEY,
	brand_origin varchar UNIQUE -- название страны в тектсовом виде 
);

CREATE TABLE car_shop.brand (
	id serial PRIMARY KEY,
	brand_name varchar NOT NULL UNIQUE, -- название страны в тектсовом виде
	brand_origin_id SMALLINT -- список стран будет коротким
);

CREATE TABLE car_shop.colour (
	id serial PRIMARY KEY,
	colour varchar NOT NULL UNIQUE -- цвет в виде текста, уникальный, не пустой
);

CREATE TABLE car_shop.model (
	id serial PRIMARY KEY,
	brand_id integer NOT NULL,
	model_name varchar NOT NULL, -- модель в виде текста, не пустой, возможно может повторяться у разных бренодов
	gasoline_consumption numeric(3, 1) -- двзначное число с дробной частью
);

CREATE TABLE car_shop.auto (
	id serial PRIMARY KEY,
	brand_id integer NOT NULL,
	model_id integer NOT NULL,
	colour_id integer NOT NULL
);


CREATE TABLE car_shop.clients (
	id serial PRIMARY KEY,
	prefix varchar, -- префикс в виде текста, может быть путсым
	first_name varchar NOT NULL, -- имя в виде текста, не пустой
	last_name varchar NOT NULL, -- фамилия в виде текста, не пустой
	jr varchar, -- приставка Jr. там где нобходима
	phone varchar -- телефон в виде текста, может быть пустым
);


CREATE TABLE car_shop.sales (
	id serial PRIMARY KEY,
	auto_id integer,
	price numeric(9,2) NOT NULL CHECK(price>=0), -- число до 7 занков и 2 знаков после запятой, проверка неотрицательных значений
	date date NOT NULL DEFAULT CURRENT_DATE, -- дата, не путстая, по умолчанию текущая дата при создании записи
	client_id integer, 
	discount SMALLINT NOT NULL CHECK(discount >=0 AND discount <= 100) -- число от 0 до 100, не путое
);




/* Заполнение данными */

/*заполнение таблицы brand_origin*/
INSERT INTO car_shop.brand_origin (brand_origin)
SELECT DISTINCT brand_origin FROM raw_data.sales;

-- TRUNCATE TABLE car_shop.model RESTART IDENTITY

/*заполнение таблицы brand*/
INSERT INTO car_shop.brand (brand_name, brand_origin_id)
SELECT DISTINCT 
	SPLIT_PART(s.auto, ' ', 1), 
	bo.id
FROM raw_data.sales AS s
INNER JOIN car_shop.brand_origin AS bo USING(brand_origin)

/*заполнение таблицы model*/
INSERT INTO car_shop.model (brand_id, model_name, gasoline_consumption)
SELECT DISTINCT 
	b.id,
	SUBSTR(SPLIT_PART(s.auto, ',', 1), STRPOS(SPLIT_PART(s.auto, ',', 1), ' ')+1), 
	s.gasoline_consumption
FROM raw_data.sales AS s
LEFT JOIN car_shop.brand AS b ON b.brand_name = SPLIT_PART(s.auto, ' ', 1);


/*заполнение таблицы colour*/
INSERT INTO car_shop.colour (colour)
SELECT DISTINCT 
	TRIM(SPLIT_PART(s.auto, ',', 2))
FROM raw_data.sales AS s


/*заполнение таблицы auto*/
INSERT INTO car_shop.auto (brand_id, model_id, colour_id)
SELECT 
	b.id,
	m.id,
	c.id
FROM raw_data.sales AS s
LEFT JOIN car_shop.brand AS b ON b.brand_name = SPLIT_PART(s.auto, ' ', 1)
LEFT JOIN car_shop.model AS m ON m.model_name = SUBSTR(SPLIT_PART(s.auto, ',', 1), STRPOS(SPLIT_PART(s.auto, ',', 1), ' ')+1)
LEFT JOIN car_shop.colour AS c ON c.colour = TRIM(SPLIT_PART(s.auto, ',', 2));


/*заполнение таблицы clients*/
INSERT INTO car_shop.clients (prefix, first_name, last_name, jr, phone)
SELECT DISTINCT 
	CASE 
		WHEN SPLIT_PART(s.person_name, '. ', 2) = '' THEN NULL
		WHEN SPLIT_PART(s.person_name, '. ', 2) <> '' THEN SPLIT_PART(s.person_name, '. ', 1) || '.'
	END,
	CASE 
		WHEN SPLIT_PART(s.person_name, '. ', 2) = '' THEN SPLIT_PART(SPLIT_PART(s.person_name, '. ', 1), ' ', 1)
		WHEN SPLIT_PART(s.person_name, '. ', 2) <> '' THEN SPLIT_PART(SPLIT_PART(s.person_name, '. ', 2), ' ', 1)
	END,
	CASE 
		WHEN SPLIT_PART(s.person_name, '. ', 2) = '' THEN SPLIT_PART(SPLIT_PART(s.person_name, '. ', 1), ' ', 2)
		WHEN SPLIT_PART(s.person_name, '. ', 2) <> '' THEN SPLIT_PART(SPLIT_PART(s.person_name, '. ', 2), ' ', 2)
	END,
	CASE 
		WHEN STRPOS(s.person_name, 'Jr.') > 0 THEN 'Jr.'
		ELSE NULL 
	END,
	s.phone
FROM raw_data.sales AS s;


/*заполнение таблицы sales*/
INSERT INTO car_shop.sales (auto_id, price, date, client_id, discount)
SELECT 
	a.id,
	s.price,
	s.date,
	cl.id,
	s.discount
FROM raw_data.sales AS s
LEFT JOIN car_shop.brand AS b ON b.brand_name = SPLIT_PART(s.auto, ' ', 1)
LEFT JOIN car_shop.model AS m ON m.model_name = SUBSTR(SPLIT_PART(s.auto, ',', 1), STRPOS(SPLIT_PART(s.auto, ',', 1), ' ')+1)
LEFT JOIN car_shop.colour AS c ON c.colour = TRIM(SPLIT_PART(s.auto, ',', 2))
LEFT JOIN car_shop.auto AS a ON a.brand_id = b.id AND a.model_id = m.id AND a.colour_id = c.id
LEFT JOIN car_shop.clients AS cl ON POSITION(cl.first_name || cl.last_name IN REPLACE(s.person_name, ' ', ''))>0
; 


/*
Задание 1 из 6
Напишите запрос, который выведет процент моделей машин, у которых нет параметра gasoline_consumption.
Вот формат итоговой таблицы:
*/
SELECT 
  ((1-COUNT(m.gasoline_consumption)::real/COUNT(*))*100)::numeric(4, 2) AS nulls_percentage_gasoline_consumption
FROM car_shop.model AS m;


/*
Задание 2 из 6
Напишите запрос, который покажет название бренда и среднюю цену его автомобилей в разбивке по всем годам с учётом скидки. 
Итоговый результат отсортируйте по названию бренда и году в восходящем порядке.
Среднюю цену округлите до второго знака после запятой.
*/
SELECT 
  b.brand_name,
  DATE_PART('year', s.date) AS YEAR,
  AVG(s.price)::numeric(9, 2) AS price_avg
FROM car_shop.sales AS S
LEFT JOIN car_shop.auto AS a ON a.id = s.auto_id
LEFT JOIN car_shop.brand AS b ON a.brand_id = b.id
GROUP BY b.brand_name, YEAR
ORDER BY b.brand_name, YEAR;


/*
Задание 3 из 6
Посчитайте среднюю цену всех автомобилей с разбивкой по месяцам в 2022 году с учётом скидки. 
Результат отсортируйте по месяцам в восходящем порядке. 
Среднюю цену округлите до второго знака после запятой.
*/

SELECT 
  DATE_PART('month', s.date) AS month,
  DATE_PART('year', s.date) AS YEAR,
  AVG(s.price)::numeric(9, 2) AS price_avg
FROM car_shop.sales AS S
GROUP BY YEAR, month 
ORDER BY YEAR, month;

/*Задание 4 из 6
Используя функцию STRING_AGG, напишите запрос, который выведет список купленных машин у каждого пользователя через запятую. 
Пользователь может купить две одинаковые машины — это нормально. 
Название машины покажите полное, с названием бренда — например: Tesla Model 3. 
Отсортируйте по имени пользователя в восходящем порядке. 
Сортировка внутри самой строки с машинами не нужна.*/

SELECT 
  CONCAT(c.first_name, ' ', c.last_name) AS person,
  STRING_AGG(CONCAT(b.brand_name, ' ', m.model_name), ', ') AS cars
FROM car_shop.sales AS s
LEFT JOIN car_shop.auto AS a ON a.id = s.auto_id
LEFT JOIN car_shop.brand AS b ON a.brand_id = b.id
LEFT JOIN car_shop.model AS m ON a.model_id = m.id
LEFT JOIN car_shop.clients AS c ON s.client_id = c.id
GROUP BY person 
ORDER BY person;


/*
Задание 5 из 6
Напишите запрос, который вернёт самую большую и самую маленькую цену продажи автомобиля с разбивкой по стране без учёта скидки. 
Цена в колонке price дана с учётом скидки.*/

SELECT 
  bo.brand_origin,
  MAX(s.price/(1-s.discount/100)) AS price_max,
  MIN(s.price/(1-s.discount/100)) AS price_min
FROM car_shop.sales AS s
LEFT JOIN car_shop.auto AS a ON a.id = s.auto_id
LEFT JOIN car_shop.brand AS b ON a.brand_id = b.id
LEFT JOIN car_shop.brand_origin AS bo ON b.brand_origin_id = bo.id
GROUP BY bo.brand_origin
;


/*Задание 6 из 6
Напишите запрос, который покажет количество всех пользователей из США. 
Это пользователи, у которых номер телефона начинается на +1.*/
SELECT
  COUNT(*) AS persons_from_usa_count
FROM car_shop.clients AS c
WHERE SUBSTR(c.phone, 1, 2)='+1';

